# The steam-api gem defaults to ENV["STEAM_API_KEY"], but ours lives in
# Rails encrypted credentials instead -- point the gem at it explicitly so
# both the web and Sidekiq processes use it (this file loads on every boot).
Steam.apikey = Rails.application.credentials.steam_key
