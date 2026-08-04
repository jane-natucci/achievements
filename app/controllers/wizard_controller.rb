class WizardController < ApplicationController
  layout "wizard"

  GAMES_TO_SHOW = 4

  before_action :require_current_user!, only: [:syncing, :sync_status, :game, :set_game, :achievement, :set_achievement]
  before_action :require_wizard_state!, only: [:achievement, :set_achievement]

  def profile
    redirect_to wizard_game_path if current_user
  end

  def create_profile
    result = SteamProfileLogin.call(params[:profile_url])

    unless result.success?
      flash.now[:alert] = result.error
      return render :profile, status: :unprocessable_entity
    end

    SyncUserAchievementProgressWorker.perform_async(result.user.id)
    result.user.update!(games_synced_at: nil)
    SyncOwnedGamesWorker.perform_async(result.user.id)
    session[:user_id] = result.user.id

    redirect_to wizard_syncing_path
  end

  def syncing
  end

  def sync_status
    render json: { done: current_user.games_synced_at.present? }
  end

  def game
    @owned_games = owned_games_in_catalog
  end

  def set_game
    game = Game.find_by(id: params[:game_id])
    return redirect_to(wizard_game_path, alert: "Select a game to continue.") unless game

    candidate_groups = SuggestStarterAchievements.call(game).map { |group| group.map(&:id) }.reject(&:blank?)
    return redirect_to(wizard_game_path, alert: "That game doesn't have achievement data yet. Try another one.") if candidate_groups.empty?

    session[:wizard] = {
      "game_id" => game.id,
      "candidate_ids" => candidate_groups,
      "selected_ids" => {},
      "notes" => {}
    }

    redirect_to wizard_achievement_path(step: 1)
  end

  def achievement
    @step = params[:step].to_i
    @total_steps = wizard_candidate_ids.size
    @candidates = current_step_candidates
    return redirect_to wizard_game_path if @candidates.blank?

    @game = current_wizard_game
    @selected_id = session.dig(:wizard, "selected_ids", @step.to_s)
  end

  def set_achievement
    @step = params[:step].to_i
    candidate_ids = wizard_candidate_ids[@step - 1]
    return redirect_to wizard_game_path if candidate_ids.blank?

    achievement_id = params[:achievement_id].presence&.to_i
    return redirect_to(wizard_achievement_path(step: @step), alert: "Pick one to continue.") unless candidate_ids.include?(achievement_id)

    session[:wizard]["selected_ids"][@step.to_s] = achievement_id
    session[:wizard]["notes"][achievement_id.to_s] = params[:note].to_s.strip.presence

    if @step < wizard_candidate_ids.size
      redirect_to wizard_achievement_path(step: @step + 1)
    else
      chain = build_chain_from_wizard!
      session.delete(:wizard)
      redirect_to chain_path(chain), notice: "Your first chain is ready!"
    end
  end

  private

  def require_current_user!
    redirect_to wizard_path unless current_user
  end

  def require_wizard_state!
    redirect_to wizard_game_path if session[:wizard].blank?
  end

  def wizard_candidate_ids
    Array(session.dig(:wizard, "candidate_ids"))
  end

  def current_wizard_game
    Game.find_by(id: session.dig(:wizard, "game_id"))
  end

  def current_step_candidates
    candidate_ids = wizard_candidate_ids[@step - 1]
    return [] if candidate_ids.blank?

    achievements_by_id = Achievement.where(id: candidate_ids).index_by(&:id)
    candidate_ids.filter_map { |id| achievements_by_id[id] }
  end

  def owned_games_in_catalog
    catalog_games = Game.where.not(steam_app_id: nil).index_by(&:steam_app_id)
    return [] if catalog_games.empty?

    owned = Steam::Player.owned_games(current_user.steam_id, params: { include_appinfo: true, include_played_free_games: true })
    owned_by_appid = Array(owned["games"]).index_by { |entry| entry["appid"] }

    matches = catalog_games.filter_map do |app_id, game|
      owned_entry = owned_by_appid[app_id]
      next unless owned_entry

      {
        game: game,
        playtime_forever: owned_entry["playtime_forever"].to_i,
        icon_url: steam_icon_url(app_id, owned_entry["img_icon_url"])
      }
    end
    matches = matches.sort_by { |entry| -entry[:playtime_forever] }

    matches.presence&.first(GAMES_TO_SHOW) || catalog_fallback(catalog_games)
  rescue StandardError
    catalog_fallback(catalog_games)
  end

  def catalog_fallback(catalog_games)
    catalog_games.values.sort_by(&:name).first(GAMES_TO_SHOW).map { |game| { game: game, playtime_forever: nil, icon_url: nil } }
  end

  def steam_icon_url(app_id, icon_hash)
    return if icon_hash.blank?

    "https://media.steampowered.com/steamcommunity/public/images/apps/#{app_id}/#{icon_hash}.jpg"
  end

  def build_chain_from_wizard!
    game = current_wizard_game
    notes = session[:wizard]["notes"] || {}
    selected_ids = session[:wizard]["selected_ids"] || {}
    ordered_ids = (1..wizard_candidate_ids.size).filter_map { |step| selected_ids[step.to_s] }
    selected_achievements = ordered_ids.map { |id| { id: id, note: notes[id.to_s] } }

    chain = Chain.new(
      title: "My First #{game.name} Chain",
      description: "A starter chain built with the onboarding wizard.",
      game: game,
      creator: current_user
    )

    ActiveRecord::Base.transaction do
      chain.save!
      SyncChainSequence.call(chain, selected_achievements)
    end

    SyncUserAchievementProgressWorker.perform_async(current_user.id)
    chain
  end
end
