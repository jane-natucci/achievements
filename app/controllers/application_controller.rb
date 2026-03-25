class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_user, :header_avatar_link_path, :header_avatar_link_label, :random_header_achievement_icon_url

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def random_header_achievement_icon_url
    random_header_achievement&.icon_unlocked
  end

  def header_avatar_link_path
    return "/achievements/" if current_user
    return achievement_path(random_header_achievement) if random_header_achievement

    "/achievements/login/"
  end

  def header_avatar_link_label
    return "Home" if current_user
    return "Open random achievement" if random_header_achievement

    "Log In"
  end

  def random_header_achievement
    @random_header_achievement ||= Achievement.where.not(icon_unlocked: [nil, ""]).order(Arel.sql("RANDOM()")).first
  end
end
