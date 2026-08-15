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
      ImportSteamGame.call(game_data["appid"], name: game_data["name"], icon_hash: game_data["img_icon_url"])
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
end
