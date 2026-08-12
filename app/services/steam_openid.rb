require "net/http"

# Minimal Steam OpenID 2.0 sign-in: redirect the user to Steam, then verify
# the signed response they're redirected back with by posting it straight
# back to Steam ("check_authentication") -- this is what actually proves the
# callback wasn't forged, unlike just trusting the returned steamid.
# https://partner.steamgames.com/doc/features/auth#website
class SteamOpenid
  PROVIDER_URL = "https://steamcommunity.com/openid/login"
  CLAIMED_ID_PATTERN = %r{\Ahttps://steamcommunity\.com/openid/id/(\d{17})\z}

  def self.authorize_url(return_to:, realm:)
    params = {
      "openid.ns" => "http://specs.openid.net/auth/2.0",
      "openid.mode" => "checkid_setup",
      "openid.return_to" => return_to,
      "openid.realm" => realm,
      "openid.identity" => "http://specs.openid.net/auth/2.0/identifier_select",
      "openid.claimed_id" => "http://specs.openid.net/auth/2.0/identifier_select"
    }
    "#{PROVIDER_URL}?#{params.to_query}"
  end

  # Returns the verified steamid64 from a Steam OpenID callback's query
  # params, or nil if the claimed identity is malformed or Steam says the
  # signature doesn't check out.
  def self.verify_steam_id(callback_params)
    new(callback_params).verify_steam_id
  end

  def initialize(callback_params)
    @callback_params = callback_params
  end

  def verify_steam_id
    match = CLAIMED_ID_PATTERN.match(callback_params["openid.claimed_id"].to_s)
    return unless match
    return unless verified_with_steam?

    match[1]
  end

  private

  attr_reader :callback_params

  def verified_with_steam?
    response = Net::HTTP.post_form(URI(PROVIDER_URL), verification_params)
    response.body.include?("is_valid:true")
  rescue StandardError
    false
  end

  def verification_params
    callback_params.to_h
                   .select { |key, _| key.to_s.start_with?("openid.") }
                   .merge("openid.mode" => "check_authentication")
  end
end
