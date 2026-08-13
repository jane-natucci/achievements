class UsersController < ApplicationController
  ACHIEVEMENT_WALL_LIMIT = 120

  def index
    @users = User.order(total_xp: :desc, created_at: :asc).limit(50)
    user_ids = @users.map(&:id)

    @achievements_unlocked_counts = UserNodeProgress.where(user_id: user_ids, status: "completed")
                                                      .group(:user_id).count
    @chains_completed_counts = UserChainProgress.where(user_id: user_ids).where.not(completed_at: nil)
                                                 .group(:user_id).count
  end

  def show
    @user = User.find(params[:id])
    @rank = User.where("total_xp > ?", @user.total_xp).count + 1
    @xp_events = @user.xp_events.order(created_at: :desc).limit(20)

    load_achievement_wall(limit: ACHIEVEMENT_WALL_LIMIT)
  end

  # Uncapped version of the wall, for "Show all" -- kept as its own page
  # (rather than lazy-loading more into #show) so the default profile load
  # stays light for players with a huge unlock history.
  def wall
    @user = User.find(params[:id])

    load_achievement_wall(limit: nil)
  end

  private

  # Pinned achievements always show first (most recently pinned first),
  # then the rest by unlock recency. Pins are capped at
  # UserAchievementPin::MAX_PINS_PER_USER (small), so it's cheap to fetch
  # them separately and fill the remaining slots around them, rather than
  # expressing this ordering as one big SQL CASE.
  def load_achievement_wall(limit:)
    @achievement_wall_total_count = @user.user_achievement_unlocks.count

    pinned_achievement_ids = @user.user_achievement_pins.order(created_at: :desc).pluck(:achievement_id)
    @pinned_achievement_ids = pinned_achievement_ids.to_set

    pinned_unlocks_by_achievement_id = @user.user_achievement_unlocks
                                             .includes(achievement: :game)
                                             .where(achievement_id: pinned_achievement_ids)
                                             .index_by(&:achievement_id)
    pinned_unlocks = pinned_achievement_ids.filter_map { |id| pinned_unlocks_by_achievement_id[id] }

    remaining = @user.user_achievement_unlocks
                      .includes(achievement: :game)
                      .where.not(achievement_id: pinned_achievement_ids)
                      .order(Arel.sql("unlocked_at DESC NULLS LAST"))
    remaining = remaining.limit([limit - pinned_unlocks.size, 0].max) if limit

    @achievement_wall = pinned_unlocks + remaining.to_a
    @viewing_own_wall = current_user == @user
    build_most_popular_chain_lookup(@achievement_wall.map(&:achievement_id))
  end

  # For each achievement on the wall, the chain (among all kept chains that
  # include it) with the most favorites -- shown in the wall popup. Batched
  # up front instead of per-tile to avoid N+1s across a potentially large wall.
  def build_most_popular_chain_lookup(achievement_ids)
    @most_popular_chain_by_achievement_id = {}
    return if achievement_ids.empty?

    nodes_by_achievement_id = ChainNode.joins(:chain)
                                        .merge(Chain.kept)
                                        .where(ref_id: achievement_ids)
                                        .includes(chain: :game)
                                        .group_by(&:ref_id)

    chain_ids = nodes_by_achievement_id.values.flatten.map(&:chain_id).uniq
    favorite_counts = UserChainProgress.where(chain_id: chain_ids, favorite: true).group(:chain_id).count

    achievement_ids.each do |achievement_id|
      chains = (nodes_by_achievement_id[achievement_id] || []).map(&:chain).uniq
      @most_popular_chain_by_achievement_id[achievement_id] = chains.max_by { |chain| favorite_counts[chain.id] || 0 }
    end
  end
end
