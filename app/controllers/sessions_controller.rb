class SessionsController < ApplicationController
  def new
  end

  def create
    result = SteamProfileLogin.call(params[:profile_url])

    unless result.success?
      flash.now[:alert] = result.error
      return render :new, status: :unprocessable_entity
    end

    SyncUserAchievementProgressWorker.perform_async(result.user.id)
    session[:user_id] = result.user.id

    redirect_to "/achievements/", notice: "Now impersonating #{result.user.display_name}."
  end

  def destroy
    session.delete(:user_id)
    redirect_to "/achievements/", notice: "Logged out."
  end
end
