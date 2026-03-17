class User < ApplicationRecord
  has_many :user_chain_progresses, dependent: :destroy
  has_many :user_node_progresses, dependent: :destroy
end
