# Pulls Steam's own GetGlobalAchievementPercentagesForApp -- the real % of
# *all* Steam players (not just our own handful of registered users) who've
# unlocked each achievement -- and persists it so AchievementRarity can use
# real population data instead of guessing from our tiny local user table.
class SyncGlobalAchievementRarity
  def self.call
    new.call
  end

  def call
    Game.where.not(steam_app_id: nil).find_each do |game|
      sync_game!(game)
    rescue StandardError
      next
    end
  end

  private

  def sync_game!(game)
    percent_by_api_name = fetch_percent_by_api_name(game)
    return if percent_by_api_name.empty?

    game.achievements.find_each do |achievement|
      percent = percent_by_api_name[achievement.steam_api_name]
      next if percent.nil?

      achievement.update!(global_unlock_pct: percent) if achievement.global_unlock_pct != percent
    end
  end

  def fetch_percent_by_api_name(game)
    Array(Steam::UserStats.achievement_percentages(game.steam_app_id)).each_with_object({}) do |entry, hash|
      hash[entry["name"]] = entry["percent"].to_f
    end
  end
end
