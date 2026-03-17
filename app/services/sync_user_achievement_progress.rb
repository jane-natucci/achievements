class SyncUserAchievementProgress
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    Game.find_each do |game|
      sync_progress_for_game!(game)
    rescue StandardError
      next
    end
  end

  private

  attr_reader :user

  def sync_progress_for_game!(game)
    player_stats = Steam::UserStats.player_achievements(game.steam_app_id, user.steam_id)
    unlocked_achievements = Array(player_stats["achievements"])
      .select { |entry| entry["achieved"].to_i == 1 }
      .index_by { |entry| entry["apiname"] }

    chain_nodes = ChainNode.joins(:chain)
                           .includes(:achievement)
                           .where(chains: { game_id: game.id })

    unlocked_chain_node_ids = chain_nodes.filter_map do |chain_node|
      achievement = chain_node.achievement
      next unless achievement

      steam_achievement = unlocked_achievements[achievement.steam_api_name]
      next unless steam_achievement

      unlocked_at =
        if steam_achievement["unlocktime"].to_i.positive?
          Time.zone.at(steam_achievement["unlocktime"].to_i)
        end

      progress = UserNodeProgress.find_or_initialize_by(user: user, chain_node: chain_node)
      progress.status = "completed"
      progress.source = "steam"
      progress.unlocked_at = unlocked_at
      progress.save! if progress.new_record? || progress.changed?

      if progress.created_at.blank? && unlocked_at.present?
        progress.update_column(:created_at, unlocked_at)
      end

      chain_node.id
    end

    user.user_node_progresses
        .where(source: "steam", chain_node_id: chain_nodes.select(:id))
        .where.not(chain_node_id: unlocked_chain_node_ids)
        .delete_all
  end
end
