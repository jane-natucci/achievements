# Fraction of players who've unlocked each achievement. Shared by CardStats
# (battle card strength) and the achievement wall (rare achievement glow) so
# both features agree on what "rare" means.
#
# Prefers Steam's own global unlock % (synced onto Achievement#global_unlock_pct
# by SyncGlobalAchievementRarity) since that reflects all Steam players, not
# just our own handful of registered users -- with a small userbase, "% of
# our users" is too noisy/coarse to mean much (e.g. 1 of 5 users already
# clears a 25% bar). Falls back to our local userbase for any achievement
# that hasn't been synced yet (new game, or a Steam API hiccup).
class AchievementRarity
  RARE_THRESHOLD = 0.05 # unlocked by at most 5% of players

  def self.pct_for(achievement_ids)
    achievement_ids = achievement_ids.uniq
    global_pct_by_id = Achievement.where(id: achievement_ids).where.not(global_unlock_pct: nil)
                                   .pluck(:id, :global_unlock_pct).to_h
    local_pct_by_id = local_pct_for(achievement_ids - global_pct_by_id.keys)

    achievement_ids.index_with do |achievement_id|
      if global_pct_by_id.key?(achievement_id)
        (global_pct_by_id[achievement_id] / 100.0).clamp(0.0, 1.0)
      else
        local_pct_by_id.fetch(achievement_id, 0.0)
      end
    end
  end

  def self.rare?(pct)
    pct <= RARE_THRESHOLD
  end

  def self.local_pct_for(achievement_ids)
    return {} if achievement_ids.empty?

    total_users = User.count.to_f
    unlock_counts = UserAchievementUnlock.where(achievement_id: achievement_ids).group(:achievement_id).count

    achievement_ids.index_with do |achievement_id|
      total_users.zero? ? 0.0 : (unlock_counts[achievement_id] || 0) / total_users
    end
  end
  private_class_method :local_pct_for
end
