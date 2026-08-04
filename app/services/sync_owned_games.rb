class SyncOwnedGames
  MIN_PLAYTIME_MINUTES = 120
  MAX_GAMES_TO_SYNC = 40

  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    candidates.each do |game_data|
      sync_game!(game_data)
    rescue StandardError
      next
    end
  end

  private

  attr_reader :user

  def candidates
    owned = Steam::Player.owned_games(user.steam_id, params: { include_appinfo: true, include_played_free_games: true })
    games = Array(owned["games"]).select { |entry| entry["playtime_forever"].to_i >= MIN_PLAYTIME_MINUTES }
    games = games.sort_by { |entry| -entry["playtime_forever"].to_i }.first(MAX_GAMES_TO_SYNC)

    known_app_ids = Game.where(steam_app_id: games.map { |entry| entry["appid"] }).pluck(:steam_app_id).to_set
    games.reject { |entry| known_app_ids.include?(entry["appid"]) }
  rescue StandardError
    []
  end

  def sync_game!(game_data)
    app_id = game_data["appid"]
    return if Game.exists?(steam_app_id: app_id)

    schema = Steam::UserStats.game_schema(app_id)
    achievement_data = Array(schema&.dig("availableGameStats", "achievements"))
    return if achievement_data.empty?

    game = Game.create!(
      steam_app_id: app_id,
      name: game_data["name"].presence || schema["gameName"],
      icon: icon_url(app_id, game_data["img_icon_url"])
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
  end

  def icon_url(app_id, icon_hash)
    return if icon_hash.blank?

    "https://media.steampowered.com/steamcommunity/public/images/apps/#{app_id}/#{icon_hash}.jpg"
  end
end
