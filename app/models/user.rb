class User < ApplicationRecord
  has_many :created_chains, class_name: "Chain", foreign_key: :creator_user_id, dependent: :nullify
  has_many :user_chain_progresses, dependent: :destroy
  has_many :user_node_progresses, dependent: :destroy
  has_many :xp_events, dependent: :destroy
  has_many :favorite_chains, -> { where(user_chain_progresses: { favorite: true }) }, through: :user_chain_progresses, source: :chain
end
