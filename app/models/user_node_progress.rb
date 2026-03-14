class UserNodeProgress < ApplicationRecord
  belongs_to :user
  belongs_to :chain_node
end
