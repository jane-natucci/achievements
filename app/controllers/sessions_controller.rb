class SessionsController < ApplicationController
  def new
  end

  def create
    steam_id = extract_steam_id(params[:profile_url].to_s)

    if steam_id.blank?
      flash.now[:alert] = "Enter a valid Steam profile URL, vanity URL, or SteamID64."
      return render :new, status: :unprocessable_entity
    end

    summary = Steam::User.summary(steam_id)

    unless summary
      flash.now[:alert] = "Could not load that Steam profile."
      return render :new, status: :unprocessable_entity
    end

    user = User.find_or_initialize_by(steam_id: steam_id)
    user.display_name = summary["personaname"]
    user.avatar_url = summary["avatarfull"].presence || summary["avatarmedium"].presence || summary["avatar"]
    user.save!

    SyncUserAchievementProgressWorker.perform_async(user.id)
    session[:user_id] = user.id

    redirect_to "/achievements/", notice: "Now impersonating #{user.display_name}."
  rescue StandardError => error
    flash.now[:alert] = "Could not impersonate that profile: #{error.message}"
    render :new, status: :unprocessable_entity
  end

  def destroy
    session.delete(:user_id)
    redirect_to "/achievements/", notice: "Logged out."
  end

  private

  def extract_steam_id(raw_value)
    return if raw_value.blank?

    value = raw_value.strip

    if value.match?(/\A\d{17}\z/)
      return value
    end

    if (match = value.match(%r{\Ahttps?://steamcommunity\.com/profiles/(\d{17})/?(?:\?.*)?\z}i))
      return match[1]
    end

    if (match = value.match(%r{\Ahttps?://steamcommunity\.com/id/([^/?#]+)/?(?:\?.*)?\z}i))
      Steam::User.vanity_to_steamid(match[1])
    end
  end
end
