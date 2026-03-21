class Game < ApplicationRecord
  EU4_STEAM_APP_ID = 236850

  has_many :achievements
  has_many :chains, -> { kept }

  def self.eu4
    find_by(steam_app_id: EU4_STEAM_APP_ID)
  end
end
