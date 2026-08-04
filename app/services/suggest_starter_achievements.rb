class SuggestStarterAchievements
  STEPS = 3
  CANDIDATES_PER_STEP = 3

  def self.call(game)
    new(game).call
  end

  def initialize(game)
    @game = game
  end

  # Splits the game's achievements into STEPS difficulty tiers (by global
  # unlock %, easiest first) and returns up to CANDIDATES_PER_STEP of the
  # most common achievements within each tier, e.g.
  # [[easy_a, easy_b, easy_c], [mid_a, mid_b, mid_c], [hard_a, hard_b, hard_c]]
  def call
    ordered = ordered_achievements
    return Array.new(STEPS) { [] } if ordered.empty?

    tiers(ordered).map { |tier| tier.first(CANDIDATES_PER_STEP) }
  end

  private

  attr_reader :game

  def ordered_achievements
    achievements = game.achievements.to_a
    percent_by_api_name = fetch_percent_by_api_name

    achievements.sort_by { |achievement| -(percent_by_api_name[achievement.steam_api_name] || -1) }
  end

  # Splits +ordered+ into STEPS contiguous, roughly equal, non-overlapping
  # slices so each step's candidates are strictly harder than the last.
  def tiers(ordered)
    size = ordered.size
    base, remainder = size.divmod(STEPS)

    start = 0
    Array.new(STEPS) do |index|
      tier_size = base + (index < remainder ? 1 : 0)
      finish = [start + tier_size, size].min
      tier = ordered[start...finish]
      start = finish
      tier
    end
  end

  def fetch_percent_by_api_name
    Array(Steam::UserStats.achievement_percentages(game.steam_app_id)).each_with_object({}) do |entry, hash|
      hash[entry["name"]] = entry["percent"].to_f
    end
  rescue StandardError
    {}
  end
end
