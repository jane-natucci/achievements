class SessionsController < ApplicationController
  def new
  end

  def create
    result = SteamProfileLogin.call(params[:profile_url])

    unless result.success?
      flash.now[:alert] = result.error
      return render :new, status: :unprocessable_entity
    end

    SyncUserAchievementProgressWorker.perform_async(result.user.id)
    session[:user_id] = result.user.id
    # Only a real Steam OpenID callback proves ownership -- explicitly clear
    # this so a previously-verified session can't carry over to whichever
    # profile URL gets pasted in next.
    session[:steam_verified] = false
    mark_online!(result.user)

    redirect_to "/achievements/", notice: "Now impersonating #{result.user.display_name}."
  end

  # GET entry point for other jane.berlin apps that already know a
  # visitor's steamid64 (e.g. eu4.jane.berlin, after its own profile-URL
  # sign-in) to link straight into that person's achievement profile here --
  # or, with an `achievement` param (a steam_api_name, e.g. from eu4's own
  # Achievement rows), straight into that specific achievement's page.
  # Deliberately keyed by steam_api_name rather than this app's internal
  # Achievement id -- the two apps' databases assign ids independently, but
  # both already store the same Steam-assigned steam_api_name, so that's
  # the only identifier safe to pass across apps without an explicit sync.
  #
  # Same trust level as the plain paste-URL flow above -- no Steam OpenID
  # proof of ownership, just a lookup/sync by steamid64 -- so it's no more
  # sensitive than the existing POST /login form.
  def login_with_steam_id
    steam_id = params[:steam_id].to_s

    if steam_id.blank?
      return redirect_to "/achievements/login/", alert: "Missing Steam ID."
    end

    result = SteamProfileLogin.call_for_steam_id(steam_id)

    unless result.success?
      return redirect_to "/achievements/login/", alert: result.error
    end

    SyncUserAchievementProgressWorker.perform_async(result.user.id)
    session[:user_id] = result.user.id
    session[:steam_verified] = false
    mark_online!(result.user)

    redirect_to landing_path_after_login(result.user), notice: "Now impersonating #{result.user.display_name}."
  end

  def steam
    # Rails blocks redirects to other hosts by default; this one is a
    # hardcoded literal Steam URL, not derived from user input, so it's safe.
    redirect_to SteamOpenid.authorize_url(return_to: login_steam_callback_url, realm: root_url), allow_other_host: true
  end

  def steam_callback
    steam_id = SteamOpenid.verify_steam_id(request.query_parameters)

    unless steam_id
      return redirect_to "/achievements/login/", alert: "Steam sign-in failed. Please try again."
    end

    result = SteamProfileLogin.call_for_steam_id(steam_id)

    unless result.success?
      return redirect_to "/achievements/login/", alert: result.error
    end

    SyncUserAchievementProgressWorker.perform_async(result.user.id)
    session[:user_id] = result.user.id
    session[:steam_verified] = true
    mark_online!(result.user)

    redirect_to "/achievements/", notice: "Signed in as #{result.user.display_name} via Steam."
  end

  def destroy
    session.delete(:user_id)
    session.delete(:steam_verified)
    redirect_to "/achievements/", notice: "Logged out."
  end

  # Pinged every ~1 minute by presence_controller.js while a logged-in
  # user has a tab open, so User#online? reflects real presence rather
  # than just "has an active session". No-ops when logged out.
  def heartbeat
    current_user&.update_column(:last_seen_at, Time.current)
    head :ok
  end

  private

  def mark_online!(user)
    user.update_column(:last_seen_at, Time.current)
  end

  # Where to land the visitor after a cross-app login: a freshly-created
  # Chain if `achievements[]` was given (see #create_chain_from_params),
  # else the achievement page named by `?achievement=` (a steam_api_name)
  # if that was given and resolves, else their own profile.
  def landing_path_after_login(user)
    chain = create_chain_from_params(user)
    return chain_path(chain) if chain

    achievement = achievement_from_params
    achievement ? achievement_path(achievement) : user_path(user)
  end

  # `?achievement=` is a steam_api_name, currently only resolved against
  # EU4 -- the only game this cross-app link exists for so far. See the
  # class comment on #login_with_steam_id for why steam_api_name and not
  # this app's internal Achievement id.
  def achievement_from_params
    steam_api_name = params[:achievement].to_s
    return nil if steam_api_name.blank?

    Game.eu4 && Achievement.find_by(game: Game.eu4, steam_api_name: steam_api_name)
  end

  # Auto-creates a Chain from `?achievements[]=` (steam_api_names, e.g.
  # eu4.jane.berlin's "create a chain from my 3 recommended achievements"
  # link) and `?description=` (e.g. eu4's AI-written "why we think so"
  # text). Mirrors ChainsController#create's happy path, minus the
  # user-facing validation there isn't a form to fail here. Returns nil
  # (falling through to #achievement_from_params, then the profile page)
  # if no achievements[] were given or none resolve against EU4.
  def create_chain_from_params(user)
    steam_api_names = Array(params[:achievements]).map(&:to_s).reject(&:blank?)
    return nil if steam_api_names.empty? || !Game.eu4

    achievements_by_name = Game.eu4.achievements.where(steam_api_name: steam_api_names).index_by(&:steam_api_name)
    ordered_achievements = steam_api_names.filter_map { |name| achievements_by_name[name] }
    return nil if ordered_achievements.empty?

    chain = Chain.new(
      title: params[:title].to_s.strip.presence || "Suggested by EU4 Strength Score",
      description: params[:description].to_s.strip.presence,
      game: Game.eu4,
      creator: user
    )
    selected_achievements = ordered_achievements.map { |achievement| { id: achievement.id, note: nil } }

    ActiveRecord::Base.transaction do
      chain.save!
      SyncChainSequence.call(chain, selected_achievements)
    end
    AwardChainCreationXp.call(chain)

    chain
  end
end
