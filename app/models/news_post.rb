# Admin-authored only -- gated by ApplicationController#admin? (see
# NewsController), not open to any signed-in user. body is markdown
# source, rendered + sanitized on the way out (see NewsHelper#render_news_body),
# not raw HTML -- unlike this model's original console-only design.
class NewsPost < ApplicationRecord
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, :body, presence: true

  scope :published, -> { where.not(published_at: nil).where(published_at: ..Time.current).order(published_at: :desc) }

  # The routes/controller here are named "news" (see config/routes.rb),
  # not the Rails-conventional "news_post" -- override so
  # polymorphic_path/comment redirects resolve to the existing news_path
  # helper instead of a nonexistent news_post_path. Overriding model_name
  # also throws off AR's own table-name inference, so pin that back
  # explicitly to the real table.
  self.table_name = "news_posts"

  def self.model_name
    ActiveModel::Name.new(self, nil, "News")
  end
end
