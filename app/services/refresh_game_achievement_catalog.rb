# ImportSteamGame only ever imports a game's achievement catalog once
# (it early-returns if the Game already exists) -- so any achievement a
# developer adds after that first import silently never appears here,
# forever. Confirmed live: EU5 was imported early with 57 achievements;
# Steam's schema has since grown to 75, and none of the other 18 were
# ever picked up, breaking any link to one of them (achievements#26).
# This re-checks an already-known game's current Steam schema and adds
# whatever's missing, by steam_api_name -- existing rows are left
# untouched (no risk of clobbering unlock/chain data tied to them).
class RefreshGameAchievementCatalog
  def self.call(game)
    new(game).call
  end

  def initialize(game)
    @game = game
  end

  def call
    schema_achievements = Array(schema&.dig("availableGameStats", "achievements"))
    return 0 if schema_achievements.empty?

    known_names = game.achievements.pluck(:steam_api_name).to_set
    missing = schema_achievements.reject { |entry| known_names.include?(entry["name"]) }

    missing.each do |entry|
      game.achievements.create!(
        steam_api_name: entry["name"],
        title: entry["displayName"],
        description: entry["description"],
        icon_unlocked: entry["icon"],
        icon_locked: entry["icongray"],
        hidden: entry["hidden"].to_i == 1
      )
    end

    missing.size
  end

  private

  attr_reader :game

  def schema
    @schema ||= Steam::UserStats.game_schema(game.steam_app_id)
  end
end
