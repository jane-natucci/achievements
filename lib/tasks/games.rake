namespace :games do
  desc "Add newly-published achievements to already-imported games' catalogs (see RefreshGameAchievementCatalog)"
  task refresh_achievement_catalogs: :environment do
    # Scoped to games with a chain -- the same set SyncUserAchievementProgress
    # already privileges for its own (per-user, per-hour) sync, for the same
    # reason: refreshing catalogs for every game anyone's ever played (3600+)
    # would be a lot of wasted Steam API calls for games nobody links to or
    # looks at again. A game only matters here once someone's actually chained
    # an achievement from it.
    Game.joins(:chains).distinct.find_each do |game|
      added = RefreshGameAchievementCatalog.call(game)
      puts "#{game.name} (#{game.steam_app_id}): added #{added} achievement(s)" if added.positive?
    rescue StandardError => e
      puts "#{game.name} (#{game.steam_app_id}): failed -- #{e.class}: #{e.message}"
    end
  end

  desc "Checks EU5's achievement icon URLs are still resolving (see CheckEu5IconUrls) -- alerts via Sentry if any broke"
  task check_eu5_icon_urls: :environment do
    CheckEu5IconUrls.call
  end
end
