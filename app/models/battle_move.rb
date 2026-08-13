class BattleMove < ApplicationRecord
  belongs_to :battle
  belongs_to :acting_battle_card, class_name: "BattleCard"
  belongs_to :target_battle_card, class_name: "BattleCard", optional: true
end
