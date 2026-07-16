# frozen_string_literal: true

# Run with:
#   bin/rails runner script/import_games_over_15_hours_with_achievements.rb
#
# This list was extracted from the saved Steam games page:
#   /Users/jane/Downloads/Steam Community __ Jane __ Games.html
# using these filters:
# - playtime_forever >= 900 minutes (15 hours)
# - has_community_visible_stats = true
#
# Already-imported games were intentionally removed from this script:
# - Garry's Mod
# - Europa Universalis IV
# - Baldur's Gate 3
# - The Elder Scrolls IV: Oblivion Remastered
# - Hearts of Iron IV
# - Crusader Kings III
#
# Assumption:
# - "Total War Rome" => "Total War: ROME REMASTERED"

GAMES_TO_IMPORT = [
  { name: "Victoria 3", steam_app_id: 529_340 },
  { name: "Tower Unite", steam_app_id: 394_690 },
  { name: "NieR:Automata", steam_app_id: 524_220 },
  { name: "SILENT HILL 2", steam_app_id: 2_124_490 },
  { name: "GRIP: Combat Racing", steam_app_id: 396_900 },
  { name: "Half-Life 2: Episode One", steam_app_id: 380 },
  { name: "Half-Life 2: Episode Two", steam_app_id: 420 },
  { name: "The Elder Scrolls V: Skyrim Special Edition", steam_app_id: 489_830 },
  { name: "Forza Horizon 5", steam_app_id: 1_551_360 },
  { name: "Forza Horizon 4", steam_app_id: 1_293_830 },
  { name: "Football Manager 2024", steam_app_id: 2_252_570 },
  { name: "Cyberpunk 2077", steam_app_id: 1_091_500 },
  { name: "Fallout 4", steam_app_id: 377_160 },
  { name: "Resident Evil Requiem", steam_app_id: 3_764_200 },
  { name: "Half-Life: Alyx", steam_app_id: 546_560 },
  { name: "Stray", steam_app_id: 1_332_010 },
  { name: "Puyo Puyo Tetris", steam_app_id: 546_050 },
  { name: "Slay the Princess", steam_app_id: 1_989_270 },
  { name: "Anno 1800", steam_app_id: 916_440 },
  { name: "Total War: EMPIRE - Definitive Edition", steam_app_id: 10_500 },
  { name: "Total War: ROME REMASTERED", steam_app_id: 885_970 },
  { name: "Total War: ROME II - Emperor Edition", steam_app_id: 214_950 },
  { name: "Total War: SHOGUN 2", steam_app_id: 201_270 },
  { name: "Total War: WARHAMMER", steam_app_id: 364_360 },
  { name: "Total War: WARHAMMER II", steam_app_id: 594_570 },
  { name: "Total War: WARHAMMER III", steam_app_id: 1_142_710 },
  { name: "Baldur's Gate: Enhanced Edition", steam_app_id: 228_280 },
  { name: "Baldur's Gate II: Enhanced Edition", steam_app_id: 257_350 },
  { name: "Divinity: Original Sin Enhanced Edition", steam_app_id: 373_420 },
  { name: "Divinity: Original Sin 2 - Definitive Edition", steam_app_id: 435_150 },
  { name: "The Talos Principle", steam_app_id: 257_510 },
  { name: "The Talos Principle 2", steam_app_id: 835_960 },
  { name: "Superliminal", steam_app_id: 1_049_410 },
  { name: "Deus Ex: Mankind Divided", steam_app_id: 337_000 },
  { name: "100% Orange Juice", steam_app_id: 282_800 },
  { name: "The Binding of Isaac: Rebirth", steam_app_id: 250_900 },
  { name: "Fallout: New Vegas", steam_app_id: 22_490 },
  { name: "Celeste", steam_app_id: 504_230 },
  { name: "DEATH STRANDING DIRECTOR'S CUT", steam_app_id: 1_850_570 },
  { name: "Persona 3 Reload", steam_app_id: 2_161_700 },
  { name: "Disco Elysium - The Final Cut", steam_app_id: 632_470 }
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
