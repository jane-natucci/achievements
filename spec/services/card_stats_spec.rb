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

    it 'scales linearly with rarity between the two extremes' do
      users = create_list(:user, 4)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: users.first, achievement: achievement, source: 'steam')

      stats = described_class.for(achievement)

      # 1 of 4 users unlocked it -> rarity_score 0.75
      expect(stats.hp).to eq((described_class::HP_BASE + described_class::HP_RANGE * 0.75).round)
      expect(stats.dmg).to eq((described_class::DMG_BASE + described_class::DMG_RANGE * 0.75).round)
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
