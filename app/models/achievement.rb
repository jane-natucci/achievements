class Achievement < ApplicationRecord
  belongs_to :game

  has_many :chain_nodes, foreign_key: :achievement_id, dependent: :nullify
end
