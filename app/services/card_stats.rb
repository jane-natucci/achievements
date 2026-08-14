# Turns an achievement's unlock rarity into battle card stats. Rarer
# achievements (fewer users have unlocked them) make stronger cards.
#
# First-pass balance, not tuned via playtesting yet: a deck of 11 cards
# (a typical 3+4+4 onboarding deck) at the midpoint rarity score averages
# ~5 damage per card, i.e. ~55 total potential damage against a 30 HP
# opponent -- comfortable headroom for stance choices and cards that never
# land a hit. See issue #57.
class CardStats
  HP_BASE = 4
  HP_RANGE = 10
  DMG_BASE = 2
  DMG_RANGE = 6

  Stats = Struct.new(:hp, :dmg)

  def self.for(achievement)
    for_achievements([achievement.id]).fetch(achievement.id)
  end

  def self.for_achievements(achievement_ids)
    achievement_ids = achievement_ids.uniq
    pct_by_id = AchievementRarity.pct_for(achievement_ids)

    achievement_ids.index_with do |achievement_id|
      rarity_score = (1.0 - pct_by_id.fetch(achievement_id)).clamp(0.0, 1.0)

      Stats.new(
        (HP_BASE + HP_RANGE * rarity_score).round,
        (DMG_BASE + DMG_RANGE * rarity_score).round
      )
    end
  end
end
