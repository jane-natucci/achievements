# frozen_string_literal: true

require "json"

# Run with:
#   bin/rails runner script/import_requested_steam_games.rb
#
# Assumptions for ambiguous titles:
# - CoH2 => Company of Heroes 2
# - Civ => Sid Meier's Civilization VI
# - ME:LE => Mass Effect Legendary Edition
# - Vermintide => Warhammer: End Times - Vermintide
# - Men of War => Men of War: Assault Squad 2
# - Tomb Raider => Tomb Raider (2013)
# - Titan Quest => Titan Quest Anniversary Edition

GAMES_TO_IMPORT = [
  { name: "Team Fortress 2", steam_app_id: 440 },
  { name: "PAYDAY 2", steam_app_id: 218_620 },
  { name: "Company of Heroes 2", steam_app_id: 231_430 },
  { name: "Warframe", steam_app_id: 230_410 },
  { name: "Mass Effect Legendary Edition", steam_app_id: 1_328_670 },
  { name: "Risk of Rain 2", steam_app_id: 632_360 },
  { name: "Terraria", steam_app_id: 105_600 },
  { name: "Killing Floor", steam_app_id: 1_250 },
  { name: "Killing Floor 2", steam_app_id: 232_090 },
  { name: "Sid Meier's Civilization V", steam_app_id: 8_930 },
  { name: "Sid Meier's Civilization VI", steam_app_id: 289_070 },
  { name: "Sid Meier's Civilization VII", steam_app_id: 1_295_660 },
  { name: "E.Y.E: Divine Cybermancy", steam_app_id: 91_700 },
  { name: "Left 4 Dead 2", steam_app_id: 550 },
  { name: "Surgeon Simulator", steam_app_id: 233_720 },
  { name: "Darkest Dungeon", steam_app_id: 262_060 },
  { name: "Path of Exile", steam_app_id: 238_960 },
  { name: "Grim Dawn", steam_app_id: 219_990 },
  { name: "Half-Life 2", steam_app_id: 220 },
  { name: "Alien Swarm", steam_app_id: 630 },
  { name: "Northgard", steam_app_id: 466_560 },
  { name: "Men of War: Assault Squad 2", steam_app_id: 244_450 },
  { name: "Stellaris", steam_app_id: 281_990 },
  { name: "Warhammer: End Times - Vermintide", steam_app_id: 235_540 },
  { name: "Barony", steam_app_id: 371_970 },
  { name: "Baldur's Gate 3", steam_app_id: 1_086_940 },
  { name: "Titan Quest Anniversary Edition", steam_app_id: 475_150 },
  { name: "Crusader Kings II", steam_app_id: 203_770 },
  { name: "Crusader Kings III", steam_app_id: 1_158_310 },
  { name: "Europa Universalis V", steam_app_id: 3_450_310 },
  { name: "Hearts of Iron IV", steam_app_id: 394_360 },
  { name: "Warhammer 40,000: Rogue Trader", steam_app_id: 2_186_680 },
  { name: "The Elder Scrolls IV: Oblivion Remastered", steam_app_id: 2_623_190 },
  { name: "Tomb Raider", steam_app_id: 203_160 },
  { name: "Halo: The Master Chief Collection", steam_app_id: 976_730 }
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
