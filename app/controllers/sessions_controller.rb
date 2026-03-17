class SessionsController < ApplicationController
  def new
  end

  def create
    steam_id = extract_steam_id(params[:profile_url].to_s)

    if steam_id.blank?
      flash.now[:alert] = "Enter a valid Steam profile URL."
      return render :new, status: :unprocessable_entity
    end

    summary = Steam::User.summary(steam_id)

    unless summary
      flash.now[:alert] = "Could not load that Steam profile."
      return render :new, status: :unprocessable_entity
    end

    user = User.find_or_initialize_by(steam_id: steam_id)
    user.display_name = summary["personaname"]
    user.avatar_url = summary["avatarfull"].presence || summary["avatarmedium"].presence || summary["avatar"]
    user.save!

    sync_user_progress!(user)
    session[:user_id] = user.id

    redirect_to "/achievements/", notice: "Now impersonating #{user.display_name}."
  rescue StandardError => error
    flash.now[:alert] = "Could not impersonate that profile: #{error.message}"
    render :new, status: :unprocessable_entity
  end

  def destroy
    session.delete(:user_id)
    redirect_to "/achievements/", notice: "Logged out."
  end

  private

  def extract_steam_id(raw_value)
    return if raw_value.blank?

    value = raw_value.strip

    if (match = value.match(%r{\Ahttps?://steamcommunity\.com/profiles/(\d+)/?\z}i))
      return match[1]
    end

    if (match = value.match(%r{\Ahttps?://steamcommunity\.com/id/([^/]+)/?\z}i))
      return Steam::User.vanity_to_steamid(match[1])
    end

    value if value.match?(/\A\d{17}\z/)
  end

  def sync_user_progress!(user)
    Game.find_each do |game|
      sync_progress_for_game!(user, game)
    rescue StandardError
      next
    end
  end

  def sync_progress_for_game!(user, game)
    player_stats = Steam::UserStats.player_achievements(game.steam_app_id, user.steam_id)
    unlocked_api_names = Array(player_stats["achievements"])
      .select { |entry| entry["achieved"].to_i == 1 }
      .map { |entry| entry["apiname"] }

    chain_nodes = ChainNode.joins(:chain)
                           .includes(:achievement)
                           .where(chains: { game_id: game.id })

    unlocked_chain_node_ids = chain_nodes.filter_map do |chain_node|
      achievement = chain_node.achievement
      next unless achievement
      next unless unlocked_api_names.include?(achievement.steam_api_name)

      UserNodeProgress.find_or_create_by!(user: user, chain_node: chain_node) do |progress|
        progress.status = "completed"
        progress.source = "steam"
      end

      chain_node.id
    end

    user.user_node_progresses
        .where(source: "steam", chain_node_id: chain_nodes.select(:id))
        .where.not(chain_node_id: unlocked_chain_node_ids)
        .delete_all
  end
end
