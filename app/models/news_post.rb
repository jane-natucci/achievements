# Admin-authored only -- created directly via console/rails runner, no
# public form exists. #show renders body with raw HTML allowed (see the
# view), which is safe only because of that -- never expose a public
# create/update path for this model without revisiting that.
class NewsPost < ApplicationRecord
  validates :title, :body, presence: true

  scope :published, -> { where.not(published_at: nil).where(published_at: ..Time.current).order(published_at: :desc) }
end
