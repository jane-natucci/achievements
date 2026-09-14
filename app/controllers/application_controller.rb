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
  #
  # A logged-in user who's never visited the news index (last_news_read_at
  # nil) falls back to their own created_at, not "everything ever
  # published" -- otherwise a new signup joining after 100 news posts
  # already existed would see the dot lit for that whole backlog, when
  # none of it was ever actually new to them. Only posts published since
  # they joined (whether or not they've since read them) count as unread.
  def unread_news?
    latest_published_at = NewsPost.published.maximum(:published_at)
    return false unless latest_published_at
    return true unless current_user

    baseline = current_user.last_news_read_at || current_user.created_at
    latest_published_at > baseline
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

    "/login/"
  end

  def header_avatar_link_label
    return "My Profile" if current_user
    return "Open random achievement" if random_header_achievement

    "Log In"
  end

  # Restricted to achievements that actually appear in some (non-discarded)
  # chain -- otherwise this could land a logged-out visitor on an
  # achievement's page with no chain to explore from there, which is the
  # whole point of clicking it in the first place.
  def random_header_achievement
    # A subquery (rather than .distinct on the joined rows directly) --
    # Postgres rejects `SELECT DISTINCT ... ORDER BY RANDOM()` since RANDOM()
    # isn't in the select list. Filtering the outer query by `id IN (...)`
    # sidesteps that (and dedupes an achievement that's in several chains)
    # while still doing the random pick in SQL via LIMIT 1.
    eligible_ids = Achievement.where.not(icon_unlocked: [nil, ""])
                               .joins(chain_nodes: :chain)
                               .merge(Chain.kept)
                               .select(:id)
    @random_header_achievement ||= Achievement.where(id: eligible_ids).order(Arel.sql("RANDOM()")).first
  end
end
