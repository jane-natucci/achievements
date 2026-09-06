class NewsController < ApplicationController
  def index
    @news_posts = NewsPost.published
  end

  def show
    @news_post = NewsPost.published.find(params[:id])
  end
end
