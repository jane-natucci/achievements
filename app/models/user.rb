class User < ApplicationRecord
  has_many :created_chains, class_name: "Chain", foreign_key: :creator_user_id, dependent: :nullify
  has_many :user_chain_progresses, dependent: :destroy
  has_many :user_node_progresses, dependent: :destroy
end
