class UsersController < ApplicationController
  def index
    @users = User.order(total_xp: :desc, created_at: :asc).limit(50)
  end

  def show
    @user = User.find(params[:id])
    @rank = User.where("total_xp > ?", @user.total_xp).count + 1
    @xp_events = @user.xp_events.order(created_at: :desc).limit(20)
  end
end
