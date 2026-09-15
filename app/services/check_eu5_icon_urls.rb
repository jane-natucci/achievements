require "net/http"

# EU5's achievement icon URLs were rewritten off Steam's dead
# steamcdn-a.akamaihd.net CDN domain onto shared.akamai.steamstatic.com
# as an experiment (see ImportSteamGame/RefreshGameAchievementCatalog's
# ICON_CDN_REWRITE_APP_IDS) -- we can't confirm the new domain is a
# permanent Valve migration rather than a temporary state, so this
# actually checks the stored URLs are still resolving instead of
# waiting for someone to notice a broken wall. Run daily via cron; only
# EU5 is checked since it's the only game with a rewritten URL to
# actually verify.
class CheckEu5IconUrls
  EU5_STEAM_APP_ID = 3_450_310
  TIMEOUT = 5

  def self.call
    new.call
  end

  def call
    broken = urls_to_check.reject { |_id, _field, url| url_ok?(url) }
    return if broken.empty?

    message = "CheckEu5IconUrls: #{broken.size} broken EU5 icon URL(s) -- " \
      "#{broken.map { |id, field, url| "achievement #{id} #{field}: #{url}" }.join('; ')}"
    Rails.logger.error(message)
    Sentry.capture_message(message) if defined?(Sentry) && Sentry.initialized?
  end

  private

  def urls_to_check
    game = Game.find_by(steam_app_id: EU5_STEAM_APP_ID)
    return [] unless game

    game.achievements.pluck(:id, :icon_unlocked, :icon_locked).flat_map do |id, icon_unlocked, icon_locked|
      [ [ id, :icon_unlocked, icon_unlocked ], [ id, :icon_locked, icon_locked ] ]
    end.select { |_id, _field, url| url.present? }
  end

  def url_ok?(url)
    uri = URI.parse(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
      open_timeout: TIMEOUT, read_timeout: TIMEOUT) { |http| http.head(uri.request_uri) }
    response.code.to_i == 200
  rescue StandardError
    false
  end
end
