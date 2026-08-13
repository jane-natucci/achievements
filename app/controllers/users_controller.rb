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

    @achievement_wall_total_count = @user.user_achievement_unlocks.count
    @achievement_wall = @user.user_achievement_unlocks
                              .includes(achievement: :game)
                              .order(Arel.sql("unlocked_at DESC NULLS LAST"))
                              .limit(ACHIEVEMENT_WALL_LIMIT)
    @pinned_achievement_ids = @user.user_achievement_pins.pluck(:achievement_id).to_set
    @viewing_own_wall = current_user == @user
    build_most_popular_chain_lookup(@achievement_wall.map(&:achievement_id))
  end

  private

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
