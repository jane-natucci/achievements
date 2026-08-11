class UsersController < ApplicationController
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
  end
end
