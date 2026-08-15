# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CardStats do
  describe '.for' do
    it 'gives the weakest stats to an achievement everyone has unlocked' do
      user = create(:user)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: user, achievement: achievement, source: 'steam')

      stats = described_class.for(achievement)

      expect(stats.hp).to eq(described_class::HP_BASE)
      expect(stats.dmg).to eq(described_class::DMG_BASE)
    end

    it 'gives the strongest stats to an achievement nobody has unlocked' do
      create(:user)
      achievement = create(:achievement)

      stats = described_class.for(achievement)

      expect(stats.hp).to eq(described_class::HP_BASE + described_class::HP_RANGE)
      expect(stats.dmg).to eq(described_class::DMG_BASE + described_class::DMG_RANGE)
    end

    it 'scales with rarity (log-weighted, not linear) between the two extremes' do
      users = create_list(:user, 4)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: users.first, achievement: achievement, source: 'steam')

      stats = described_class.for(achievement)

      # 1 of 4 users unlocked it -> pct 0.25 -> log-scaled rarity_score
      rarity_score = -Math.log10(0.25) / described_class::PCT_LOG_SPAN
      expect(stats.hp).to eq((described_class::HP_BASE + described_class::HP_RANGE * rarity_score).round)
      expect(stats.dmg).to eq((described_class::DMG_BASE + described_class::DMG_RANGE * rarity_score).round)
    end

    it "spreads two similarly-rare achievements' stats further apart than a linear scale would" do
      create(:user)
      common = create(:achievement)
      rare = create(:achievement)
      # Both under a global sync -- the case a themed achievement chain
      # commonly hits, where a linear pct scale barely differentiates cards.
      common.update!(global_unlock_pct: 20.0)
      rare.update!(global_unlock_pct: 5.0)

      stats = described_class.for_achievements([common.id, rare.id])

      linear_gap = (0.20 - 0.05) * described_class::HP_RANGE
      actual_gap = stats[rare.id].hp - stats[common.id].hp
      expect(actual_gap).to be > linear_gap
    end

    it "spreads a whole deck across the full stat range even when every card's real rarity is clustered close together" do
      create(:user)
      most_common, middle, rarest = Array.new(3) { create(:achievement) }
      # A themed chain's achievements often all land in a narrow band like
      # this -- that's exactly the case that used to leave every card in
      # the deck reading as nearly identical.
      most_common.update!(global_unlock_pct: 70.0)
      middle.update!(global_unlock_pct: 65.0)
      rarest.update!(global_unlock_pct: 60.0)

      stats = described_class.for_achievements([most_common.id, middle.id, rarest.id])

      expect(stats[most_common.id].hp).to eq(described_class::HP_BASE)
      expect(stats[rarest.id].hp).to eq(described_class::HP_BASE + described_class::HP_RANGE)
      expect(stats[middle.id].hp).to be_between(described_class::HP_BASE, described_class::HP_BASE + described_class::HP_RANGE)
    end

    it 'does not divide by zero when there are no registered users' do
      achievement = create(:achievement)

      expect { described_class.for(achievement) }.not_to raise_error
    end
  end

  describe '.for_achievements' do
    it 'batches the lookup for multiple achievements in one call' do
      user = create(:user)
      common = create(:achievement)
      rare = create(:achievement)
      UserAchievementUnlock.create!(user: user, achievement: common, source: 'steam')

      stats = described_class.for_achievements([common.id, rare.id])

      expect(stats[common.id].hp).to eq(described_class::HP_BASE)
      expect(stats[rare.id].hp).to eq(described_class::HP_BASE + described_class::HP_RANGE)
    end
  end
end
