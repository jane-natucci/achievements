class AchievementsController < ApplicationController
  NEWS_PAGE_SIZE = 30

  def index
    @page = [params[:page].to_i, 1].max
    # A chain with a lot of achievements floods the feed with one
    # "added X to a chain" row per achievement -- the chain_created row
    # already summarizes the count (see UsersHelper#xp_event_description),
    # so skip the individual rows here.
    visible_events = XpEvent.where.not(reason: "achievement_added")
    @recent_events = visible_events.includes(:user).order(created_at: :desc)
                                    .offset((@page - 1) * NEWS_PAGE_SIZE).limit(NEWS_PAGE_SIZE)
    @has_next_page = visible_events.count > @page * NEWS_PAGE_SIZE

    chains = Chain.kept
    @total_chains = chains.size
    @total_achievements = ChainNode.joins(:chain).where(chain_id: chains.select(:id)).count
    @filter_games = Game.joins(:chains).distinct.order(:name)
  end

  def show
    @achievement = Achievement.includes(:game).find(params[:id])
    @chain_nodes = @achievement.chain_nodes.includes(chain: :game).joins(:chain).merge(Chain.kept).order(created_at: :asc)

    # One combined feed of interactions with this achievement -- unlocks and
    # favorites, interleaved by time -- rather than two separate lists.
    # Both event types are already recorded as XpEvents (favoriting at
    # amount 0, see AwardXp), so this is just a union over reason/subject.
    unlock_events = XpEvent.where(reason: "achievement_unlocked", subject_type: "ChainNode", subject_id: @achievement.chain_nodes.select(:id))
    favorite_events = XpEvent.where(reason: "achievement_favorited", subject_type: "Achievement", subject_id: @achievement.id)
    @history = unlock_events.or(favorite_events).includes(:user).order(created_at: :desc)

    @favorited = current_user.present? && current_user.user_achievement_favorites.exists?(achievement: @achievement)
    @favorite_count = UserAchievementFavorite.where(achievement: @achievement).count

    @already_unlocked = current_user.present? && current_user.user_achievement_unlocks.exists?(achievement: @achievement)
    @pinned = current_user.present? && current_user.user_achievement_pins.exists?(achievement: @achievement)
    @can_pin_more = current_user.present? && current_user.user_achievement_pins.count < UserAchievementPin::MAX_PINS_PER_USER
  end

  def help
  end

  # Public GET entry point for other jane.berlin apps (e.g. eu4.jane.berlin)
  # to link straight to an achievement's info page, resolved by
  # steam_api_name -- the only identifier both apps' databases agree on,
  # since each assigns its own internal ids independently. Deliberately
  # doesn't touch the session: viewing an achievement's public info page
  # doesn't need a login, unlike SessionsController#login_with_steam_id
  # (used instead when the visitor actually needs to be signed in, e.g.
  # to auto-create a chain).
  def by_steam_api_name
    achievement = Game.eu4 && Achievement.find_by(game: Game.eu4, steam_api_name: params[:steam_api_name])
    return redirect_to("/achievements/", alert: "Unknown achievement.") unless achievement

    redirect_to achievement_path(achievement)
  end

  def favorite
    return redirect_to("/achievements/login/", alert: "Log in to save achievements.") unless current_user

    achievement = Achievement.find(params[:id])
    favorite = UserAchievementFavorite.find_or_initialize_by(user: current_user, achievement: achievement)
    if favorite.new_record?
      favorite.save!
      AwardXp.call(user: current_user, amount: 0, reason: "achievement_favorited", subject: achievement)
    end

    redirect_back fallback_location: achievement_path(achievement), notice: "Achievement saved to your library."
  end

  def unfavorite
    return redirect_to("/achievements/login/", alert: "Log in to manage saved achievements.") unless current_user

    achievement = Achievement.find(params[:id])
    favorite = UserAchievementFavorite.find_by(user: current_user, achievement: achievement)
    if favorite
      favorite.destroy
      XpEvent.where(user: current_user, reason: "achievement_favorited", subject: achievement).destroy_all
    end

    redirect_back fallback_location: achievement_path(achievement), notice: "Achievement removed from your library."
  end

  def pin
    return redirect_to("/achievements/login/", alert: "Log in to pin achievements.") unless current_user

    achievement = Achievement.find(params[:id])
    pin = current_user.user_achievement_pins.new(achievement: achievement)

    if pin.save
      redirect_back fallback_location: achievement_path(achievement), notice: "Pinned to your wall."
    else
      redirect_back fallback_location: achievement_path(achievement), alert: pin.errors.full_messages.to_sentence
    end
  end

  def unpin
    return redirect_to("/achievements/login/", alert: "Log in to manage your wall.") unless current_user

    achievement = Achievement.find(params[:id])
    current_user.user_achievement_pins.find_by(achievement: achievement)&.destroy

    redirect_back fallback_location: achievement_path(achievement), notice: "Unpinned."
  end
end
