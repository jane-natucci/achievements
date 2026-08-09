class XpEvent < ApplicationRecord
  belongs_to :user
  belongs_to :subject, polymorphic: true, optional: true
end
