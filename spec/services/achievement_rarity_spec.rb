# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementRarity do
  describe '.pct_for' do
    it 'gives 0.0 to an achievement nobody has unlocked' do
      create(:user)
      achievement = create(:achievement)

      pct_by_id = described_class.pct_for([achievement.id])

      expect(pct_by_id[achievement.id]).to eq(0.0)
    end

    it 'gives 1.0 to an achievement every registered user has unlocked' do
      user = create(:user)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: user, achievement: achievement, source: 'steam')

      pct_by_id = described_class.pct_for([achievement.id])

      expect(pct_by_id[achievement.id]).to eq(1.0)
    end

    it 'divides by the total registered user count, not just unlockers' do
      users = create_list(:user, 4)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: users.first, achievement: achievement, source: 'steam')

      pct_by_id = described_class.pct_for([achievement.id])

      expect(pct_by_id[achievement.id]).to eq(0.25)
    end

    it 'does not divide by zero when there are no registered users' do
      achievement = create(:achievement)

      expect { described_class.pct_for([achievement.id]) }.not_to raise_error
    end
  end

  describe '.rare?' do
    it 'treats anything at or below the threshold as rare' do
      expect(described_class.rare?(described_class::RARE_THRESHOLD)).to be(true)
      expect(described_class.rare?(0.0)).to be(true)
    end

    it 'treats anything above the threshold as not rare' do
      expect(described_class.rare?(described_class::RARE_THRESHOLD + 0.01)).to be(false)
      expect(described_class.rare?(1.0)).to be(false)
    end
  end
end
