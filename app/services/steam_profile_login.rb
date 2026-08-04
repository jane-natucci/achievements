class SteamProfileLogin
  Result = Struct.new(:user, :error, keyword_init: true) do
    def success?
      error.nil?
    end
  end

  def self.call(profile_url)
    new(profile_url).call
  end

  def initialize(profile_url)
    @profile_url = profile_url
  end

  def call
    steam_id = extract_steam_id(profile_url.to_s)
    return Result.new(error: "Enter a valid Steam profile URL, vanity URL, or SteamID64.") if steam_id.blank?

    summary = Steam::User.summary(steam_id)
    return Result.new(error: "Could not load that Steam profile.") unless summary

    user = User.find_or_initialize_by(steam_id: steam_id)
    user.display_name = summary["personaname"]
    user.avatar_url = summary["avatarfull"].presence || summary["avatarmedium"].presence || summary["avatar"]
    user.save!

    Result.new(user: user)
  rescue StandardError => error
    Result.new(error: "Could not impersonate that profile: #{error.message}")
  end

  private

  attr_reader :profile_url

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
