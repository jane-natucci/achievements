# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AchievementRarity do
  describe '.pct_for' do
    it "uses Steam's synced global_unlock_pct when present, converted to a 0..1 fraction" do
      achievement = create(:achievement, global_unlock_pct: 12.5)

      pct_by_id = described_class.pct_for([achievement.id])

      expect(pct_by_id[achievement.id]).to eq(0.125)
    end

    it 'falls back to our own userbase when global_unlock_pct has never been synced' do
      users = create_list(:user, 4)
      achievement = create(:achievement, global_unlock_pct: nil)
      UserAchievementUnlock.create!(user: users.first, achievement: achievement, source: 'steam')

      pct_by_id = described_class.pct_for([achievement.id])

      expect(pct_by_id[achievement.id]).to eq(0.25)
    end

    it 'gives 0.0 to an unsynced achievement nobody in our userbase has unlocked' do
      create(:user)
      achievement = create(:achievement, global_unlock_pct: nil)

      pct_by_id = described_class.pct_for([achievement.id])

      expect(pct_by_id[achievement.id]).to eq(0.0)
    end

    it 'does not divide by zero when there are no registered users and nothing is synced' do
      achievement = create(:achievement, global_unlock_pct: nil)

      expect { described_class.pct_for([achievement.id]) }.not_to raise_error
    end

    it 'mixes synced and unsynced achievements correctly in the same batch' do
      users = create_list(:user, 2)
      synced = create(:achievement, global_unlock_pct: 40.0)
      unsynced = create(:achievement, global_unlock_pct: nil)
      UserAchievementUnlock.create!(user: users.first, achievement: unsynced, source: 'steam')

      pct_by_id = described_class.pct_for([synced.id, unsynced.id])

      expect(pct_by_id[synced.id]).to eq(0.4)
      expect(pct_by_id[unsynced.id]).to eq(0.5)
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
