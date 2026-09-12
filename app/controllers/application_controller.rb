class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :steam_verified?, :header_avatar_link_path, :header_avatar_link_label,
                :random_header_achievement_icon_url, :unread_news?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  # A logged-out visitor has nowhere to persist "I've seen this" (no
  # cookie-based tracking here, just this one column on User), so they
  # always see the dot as long as any news exists -- the alternative
  # (never showing it to them) would just hide news from anyone who
  # hasn't logged in, which defeats the point of surfacing it at all.
  def unread_news?
    latest_published_at = NewsPost.published.maximum(:published_at)
    return false unless latest_published_at

    current_user.nil? || current_user.last_news_read_at.nil? || latest_published_at > current_user.last_news_read_at
  end

  # True only when the current session was established via a real Steam
  # OpenID sign-in (not the paste-a-profile-URL flow), which is the only
  # path that actually proves the visitor owns the Steam account.
  def steam_verified?
    session[:steam_verified].present?
  end

  def random_header_achievement_icon_url
    random_header_achievement&.icon_unlocked
  end

  def header_avatar_link_path
    return user_path(current_user) if current_user
    return achievement_path(random_header_achievement) if random_header_achievement

    "/achievements/login/"
  end

  def header_avatar_link_label
    return "My Profile" if current_user
    return "Open random achievement" if random_header_achievement

    "Log In"
  end

  def random_header_achievement
    @random_header_achievement ||= Achievement.where.not(icon_unlocked: [nil, ""]).order(Arel.sql("RANDOM()")).first
  end
end
