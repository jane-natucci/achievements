class Game < ApplicationRecord
  EU4_STEAM_APP_ID = 236850

  # Paradox games with an achievements page on paradoxwikis.com, keyed by
  # steam_app_id -- used to link an achievement's own wiki entry from its
  # show page (see AchievementsHelper#wiki_achievement_url). Only EU4 is
  # actually seeded here yet; HOI4/CK3/CK2 are listed ahead of having any
  # achievements synced for them, same as eu4's sibling paradox-scores app
  # treats its own not-yet-launched games -- inert until that game exists.
  WIKI_ACHIEVEMENTS_URLS = {
    EU4_STEAM_APP_ID => "https://eu4.paradoxwikis.com/Achievements",
    394_360 => "https://hoi4.paradoxwikis.com/Achievements", # Hearts of Iron IV
    1_158_310 => "https://ck3.paradoxwikis.com/Achievements", # Crusader Kings III
    203_770 => "https://ck2.paradoxwikis.com/Achievements" # Crusader Kings II
  }.freeze

  has_many :achievements
  has_many :chains, -> { kept }

  def self.eu4
    find_by(steam_app_id: EU4_STEAM_APP_ID)
  end

  def wiki_achievements_url
    WIKI_ACHIEVEMENTS_URLS[steam_app_id]
  end
end
