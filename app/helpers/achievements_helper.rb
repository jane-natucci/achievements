module AchievementsHelper
  # The wiki page section is just an anchor built from the achievement's
  # own title -- there's no per-achievement id to link against, so this is
  # a best-effort match (the wiki's exact heading can occasionally differ
  # slightly) rather than a guaranteed-correct deep link. nil for a game
  # without a paradoxwikis.com achievements page (see Game::WIKI_ACHIEVEMENTS_URLS).
  def wiki_achievement_url(achievement)
    base = achievement.game&.wiki_achievements_url
    return unless base

    "#{base}##{achievement.title.tr(" ", "_")}"
  end

  def steam_store_url(achievement)
    app_id = achievement.game&.steam_app_id
    return unless app_id

    "https://store.steampowered.com/app/#{app_id}"
  end
end
