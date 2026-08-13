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

    sync_first_class_unlocks!(game, unlocked_achievements)

    chain_nodes = ChainNode.joins(:chain)
                           .includes(:achievement, :chain)
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
      already_completed = progress.persisted? && progress.status == "completed"
      progress.status = "completed"
      progress.source = "steam"
      progress.unlocked_at = unlocked_at
      progress.save! if progress.new_record? || progress.changed?

      # Backdate to the real Steam unlock time -- otherwise an achievement
      # someone unlocked long ago, only just added to a chain, reads as
      # having happened "now" (both here and on the XpEvent below).
      if progress.previously_new_record? && unlocked_at.present?
        progress.update_column(:created_at, unlocked_at)
      end

      unless already_completed
        AwardXp.call(user: user, amount: XpRules::ACHIEVEMENT_UNLOCKED, reason: "achievement_unlocked", subject: chain_node, occurred_at: unlocked_at)
      end

      chain_node.id
    end

    user.user_node_progresses
        .where(source: "steam", chain_node_id: chain_nodes.select(:id))
        .where.not(chain_node_id: unlocked_chain_node_ids)
        .delete_all

    award_chain_completion_bonuses!(chain_nodes, unlocked_chain_node_ids)
  end

  # Tracks unlocks as a first-class fact independent of chains -- an
  # achievement can be genuinely unlocked on Steam without ever being added
  # to any chain, and the achievement wall (profile) needs to show all of
  # those, not just the ones that happen to be chain nodes.
  def sync_first_class_unlocks!(game, unlocked_achievements)
    still_unlocked_ids = game.achievements.filter_map do |achievement|
      steam_achievement = unlocked_achievements[achievement.steam_api_name]
      next unless steam_achievement

      unlocked_at =
        if steam_achievement["unlocktime"].to_i.positive?
          Time.zone.at(steam_achievement["unlocktime"].to_i)
        end

      unlock = UserAchievementUnlock.find_or_initialize_by(user: user, achievement: achievement)
      unlock.unlocked_at = unlocked_at
      unlock.source = "steam"
      unlock.save! if unlock.new_record? || unlock.changed?

      achievement.id
    end

    user.user_achievement_unlocks
        .where(source: "steam", achievement_id: game.achievement_ids)
        .where.not(achievement_id: still_unlocked_ids)
        .delete_all
  end

  def award_chain_completion_bonuses!(chain_nodes, unlocked_chain_node_ids)
    unlocked_set = unlocked_chain_node_ids.to_set

    chain_nodes.group_by(&:chain_id).each_value do |nodes|
      next unless nodes.all? { |node| unlocked_set.include?(node.id) }

      chain = nodes.first.chain
      progress = UserChainProgress.find_or_initialize_by(user: user, chain: chain)
      next if progress.completed_at.present?

      progress.completed_at = Time.current
      progress.save!
      AwardXp.call(user: user, amount: XpRules::CHAIN_COMPLETED, reason: "chain_completed", subject: chain)
    end
  end
end
