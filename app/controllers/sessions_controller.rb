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
    # Only a real Steam OpenID callback proves ownership -- explicitly clear
    # this so a previously-verified session can't carry over to whichever
    # profile URL gets pasted in next.
    session[:steam_verified] = false

    redirect_to "/achievements/", notice: "Now impersonating #{result.user.display_name}."
  end

  def steam
    # Rails blocks redirects to other hosts by default; this one is a
    # hardcoded literal Steam URL, not derived from user input, so it's safe.
    redirect_to SteamOpenid.authorize_url(return_to: login_steam_callback_url, realm: root_url), allow_other_host: true
  end

  def steam_callback
    steam_id = SteamOpenid.verify_steam_id(request.query_parameters)

    unless steam_id
      return redirect_to "/achievements/login/", alert: "Steam sign-in failed. Please try again."
    end

    result = SteamProfileLogin.call_for_steam_id(steam_id)

    unless result.success?
      return redirect_to "/achievements/login/", alert: result.error
    end

    SyncUserAchievementProgressWorker.perform_async(result.user.id)
    session[:user_id] = result.user.id
    session[:steam_verified] = true

    redirect_to "/achievements/", notice: "Signed in as #{result.user.display_name} via Steam."
  end

  def destroy
    session.delete(:user_id)
    session.delete(:steam_verified)
    redirect_to "/achievements/", notice: "Logged out."
  end
end
