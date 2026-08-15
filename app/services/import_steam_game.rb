# Imports a single game (+ its achievement catalog) from Steam if we don't
# already have it. Shared by SyncOwnedGames (onboarding, bulk import capped
# to a player's top N games by playtime) and SyncUserAchievementProgress
# (ongoing sync, which needs to pick up a game a player starts *after*
# onboarding regardless of that cap).
class ImportSteamGame
  def self.call(app_id, name: nil, icon_hash: nil)
    new(app_id, name: name, icon_hash: icon_hash).call
  end

  def initialize(app_id, name: nil, icon_hash: nil)
    @app_id = app_id
    @name = name
    @icon_hash = icon_hash
  end

  def call
    existing = Game.find_by(steam_app_id: app_id)
    return existing if existing

    achievement_data = Array(schema&.dig("availableGameStats", "achievements"))
    return if achievement_data.empty?

    game = Game.create!(
      steam_app_id: app_id,
      name: name.presence || schema["gameName"],
      icon: icon_url
    )

    achievement_data.each do |entry|
      game.achievements.create!(
        steam_api_name: entry["name"],
        title: entry["displayName"],
        description: entry["description"],
        icon_unlocked: entry["icon"],
        icon_locked: entry["icongray"],
        hidden: entry["hidden"].to_i == 1
      )
    end

    game
  end

  private

  attr_reader :app_id, :name, :icon_hash

  def schema
    @schema ||= Steam::UserStats.game_schema(app_id)
  end

  def icon_url
    return if icon_hash.blank?

    "https://media.steampowered.com/steamcommunity/public/images/apps/#{app_id}/#{icon_hash}.jpg"
  end
end
