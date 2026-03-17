# frozen_string_literal: true

# Run with:
#   bin/rails runner script/import_synthetik_games.rb

GAMES_TO_IMPORT = [
  { name: "SYNTHETIK: Legion Rising", steam_app_id: 528_230 },
  { name: "SYNTHETIK 2", steam_app_id: 1_471_410 }
].freeze

def upsert_game!(name:, steam_app_id:)
  game = Game.find_or_initialize_by(steam_app_id: steam_app_id)
  game.name = name
  game.save! if game.new_record? || game.changed?
  game
end

def import_achievements_for!(game)
  result = Steam::UserStats.game_schema(game.steam_app_id.to_s)
  achievements = result.dig("availableGameStats", "achievements") || []

  achievements.each do |achievement_data|
    achievement = Achievement.find_or_initialize_by(
      game: game,
      steam_api_name: achievement_data.fetch("name")
    )

    achievement.hidden = achievement_data["hidden"].to_i != 0
    achievement.description = achievement_data["description"]
    achievement.icon_unlocked = achievement_data["icon"]
    achievement.icon_locked = achievement_data["icongray"]
    achievement.title = achievement_data["displayName"]
    achievement.save! if achievement.new_record? || achievement.changed?
  end

  achievements.size
end

GAMES_TO_IMPORT.each do |game_data|
  game = upsert_game!(**game_data)
  achievement_count = import_achievements_for!(game)
  puts "Imported #{achievement_count} achievements for #{game.name} (#{game.steam_app_id})"
rescue StandardError => error
  warn "Failed to import #{game_data[:name]} (#{game_data[:steam_app_id]}): #{error.class} - #{error.message}"
end
