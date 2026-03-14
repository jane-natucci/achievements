class UserChainProgress < ApplicationRecord
  belongs_to :user
  belongs_to :chain
end
