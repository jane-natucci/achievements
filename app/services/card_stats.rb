# Turns an achievement's unlock rarity into battle card stats. Rarer
# achievements (fewer players have unlocked them) make dramatically
# stronger cards.
#
# A chain is, by definition, a themed group of achievements -- which in
# practice means their unlock rates tend to cluster together (a set of
# hard achievements from the same late-game area, or a run of easy
# story-progression ones). Mapping each card's stats off a single global
# curve, however the curve is shaped, means a whole deck can land within
# a point of itself: every card in a "rare" chain reads as top-tier, every
# card in a "common" chain reads as bottom-tier, and either way nothing in
# the deck actually feels different from anything else in it.
#
# So stats are relative to the *deck being played*, not the global
# percentage in isolation: rarity is first log-scaled (unlock rates are
# skewed, so equal percentage gaps don't mean equal rarity gaps -- 1% vs
# 5% is a much bigger deal than 41% vs 45%), then that whole deck's scores
# are stretched to fill the full HP/DMG range end to end. The rarest card
# in *this* deck always plays as the strongest, the most common as the
# weakest, whatever the deck's absolute rarity level -- guaranteeing a
# felt-in-play spread no matter which chain gets battled. See issue #57.
class CardStats
  HP_BASE = 3
  HP_RANGE = 12
  DMG_BASE = 1
  DMG_RANGE = 7

  # Percentages at or below this floor all count as maximally rare --
  # log10 blows up at exactly 0, and anything under ~0.1% is noise more
  # than a meaningful distinction anyway. Also sets how many decades of
  # unlock-rate (0.1% .. 100%) the log scale is stretched across before
  # the per-deck normalization below rescales it further.
  MIN_PCT = 0.001
  PCT_LOG_SPAN = -Math.log10(MIN_PCT)

  Stats = Struct.new(:hp, :dmg)

  def self.for(achievement)
    for_achievements([achievement.id]).fetch(achievement.id)
  end

  def self.for_achievements(achievement_ids)
    achievement_ids = achievement_ids.uniq
    pct_by_id = AchievementRarity.pct_for(achievement_ids)
    log_score_by_id = pct_by_id.transform_values { |pct| log_rarity_score(pct) }
    scores = log_score_by_id.values
    score_floor = scores.min
    score_ceiling = scores.max

    achievement_ids.index_with do |achievement_id|
      rarity_score = normalize(log_score_by_id.fetch(achievement_id), score_floor, score_ceiling)

      Stats.new(
        (HP_BASE + HP_RANGE * rarity_score).round,
        (DMG_BASE + DMG_RANGE * rarity_score).round
      )
    end
  end

  def self.log_rarity_score(pct)
    clamped_pct = pct.clamp(MIN_PCT, 1.0)
    (-Math.log10(clamped_pct) / PCT_LOG_SPAN).clamp(0.0, 1.0)
  end
  private_class_method :log_rarity_score

  # Rescales a score against the min/max seen across the same
  # for_achievements call, so that deck's rarest and most common cards
  # always land on the full 0..1 range regardless of how tightly (or
  # widely) their real percentages happen to cluster. A single-achievement
  # batch (score_floor == score_ceiling, nothing to stretch against) falls
  # back to the un-rescaled absolute score -- still the right answer for a
  # standalone lookup like CardStats.for.
  def self.normalize(score, score_floor, score_ceiling)
    return score if score_ceiling == score_floor

    (score - score_floor) / (score_ceiling - score_floor)
  end
  private_class_method :normalize
end
