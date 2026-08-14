# Fraction of registered users who've unlocked each achievement. Shared by
# CardStats (battle card strength) and the achievement wall (rare achievement
# glow) so both features agree on what "rare" means.
class AchievementRarity
  RARE_THRESHOLD = 0.25 # unlocked by at most 25% of registered users

  def self.pct_for(achievement_ids)
    achievement_ids = achievement_ids.uniq
    total_users = User.count.to_f
    unlock_counts = UserAchievementUnlock.where(achievement_id: achievement_ids).group(:achievement_id).count

    achievement_ids.index_with do |achievement_id|
      total_users.zero? ? 0.0 : (unlock_counts[achievement_id] || 0) / total_users
    end
  end

  def self.rare?(pct)
    pct <= RARE_THRESHOLD
  end
end
