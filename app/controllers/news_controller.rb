class NewsController < ApplicationController
  before_action :require_admin!, only: [ :new, :create, :edit, :update ]
  before_action :set_news_post, only: [ :show, :edit, :update ]

  def index
    # Admin sees drafts too (so there's somewhere to find/finish one),
    # everyone else only ever sees what's actually published.
    @news_posts = admin? ? NewsPost.order(Arel.sql("published_at IS NULL DESC, published_at DESC, created_at DESC")) : NewsPost.published
    current_user&.update!(last_news_read_at: Time.current)
  end

  def show
  end

  def new
    @news_post = NewsPost.new
  end

  def create
    @news_post = NewsPost.new(news_post_params)
    @news_post.published_at = Time.current if publish_now?

    if @news_post.save
      redirect_to news_path(@news_post), notice: "Posted."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @news_post.assign_attributes(news_post_params)
    @news_post.published_at = Time.current if publish_now? && @news_post.published_at.blank?

    if @news_post.save
      redirect_to news_path(@news_post), notice: "Updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Admin can preview their own drafts; everyone else 404s on one, same
  # as before this feature existed (see the "404s for an unpublished
  # post" spec).
  def set_news_post
    @news_post = admin? ? NewsPost.find(params[:id]) : NewsPost.published.find(params[:id])
  end

  # NewsPost.model_name is overridden (see the model) to make
  # polymorphic_path/comment redirects resolve to the real news_path
  # helper -- that override also changes form_with's default param key
  # away from the Rails-conventional "news_post" to "news", which is what
  # actually gets submitted. Confirmed live: the original :news_post here
  # raised ActionController::ParameterMissing on every real submission.
  def news_post_params
    params.require(:news).permit(:title, :body)
  end

  def publish_now?
    params.dig(:news, :publish_now) == "1"
  end

  def require_admin!
    return if admin?

    redirect_to news_index_path, alert: "Not authorized."
  end
end
