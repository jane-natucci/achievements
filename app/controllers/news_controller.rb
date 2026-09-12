class NewsController < ApplicationController
  def index
    @news_posts = NewsPost.published
    current_user&.update!(last_news_read_at: Time.current)
  end

  def show
    @news_post = NewsPost.published.find(params[:id])
  end
end
