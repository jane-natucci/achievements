# frozen_string_literal: true

# Run with:
#   bin/rails runner script/import_persona_4_golden.rb

STEAM_APP_ID = 1_113_000
GAME_NAME = "Persona 4 Golden"

game = Game.find_or_initialize_by(steam_app_id: STEAM_APP_ID)
game.name = GAME_NAME
game.save! if game.new_record? || game.changed?

result = Steam::UserStats.game_schema(STEAM_APP_ID.to_s)
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

puts "Imported #{achievements.size} achievements for #{game.name} (#{game.steam_app_id})"
