class Achievement < ApplicationRecord
  belongs_to :game

  has_many :chain_nodes, foreign_key: :ref_id, dependent: :nullify
  has_many :comments, as: :commentable, dependent: :destroy
  has_many :user_achievement_favorites, dependent: :destroy
end
