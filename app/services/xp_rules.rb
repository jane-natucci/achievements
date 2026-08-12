module XpRules
  PROFILE_CREATED = 100
  ACHIEVEMENT_UNLOCKED = 5
  CHAIN_CREATED = 50
  CHAIN_DESCRIPTION_BONUS = 25
  ACHIEVEMENT_ADDED_TO_CHAIN = 5
  ACHIEVEMENT_NOTE_BONUS = 3
  CHAIN_COMPLETED = 100
  # One-time nudge to try commenting, deliberately not per-comment -- unlike
  # every other XP source here, comments have no natural rate limit, so
  # rewarding volume would make the leaderboard easy to game.
  FIRST_COMMENT_BONUS = 10
end
