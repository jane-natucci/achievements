# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAchievementPin do
  describe 'pin limit' do
    let(:user) { create(:user) }
    let(:game) { create(:game) }

    it "allows up to #{described_class::MAX_PINS_PER_USER} pins" do
      described_class::MAX_PINS_PER_USER.times do
        achievement = create(:achievement, game: game)
        pin = described_class.new(user: user, achievement: achievement)
        expect(pin).to be_valid
        pin.save!
      end

      expect(user.user_achievement_pins.count).to eq(described_class::MAX_PINS_PER_USER)
    end

    it "rejects a pin past the limit" do
      described_class::MAX_PINS_PER_USER.times { described_class.create!(user: user, achievement: create(:achievement, game: game)) }

      extra = described_class.new(user: user, achievement: create(:achievement, game: game))

      expect(extra).not_to be_valid
      expect(extra.errors[:base]).to include(a_string_matching(/up to #{described_class::MAX_PINS_PER_USER}/))
    end

    it "doesn't count another user's pins toward the limit" do
      other_user = create(:user)
      described_class::MAX_PINS_PER_USER.times { described_class.create!(user: other_user, achievement: create(:achievement, game: game)) }

      pin = described_class.new(user: user, achievement: create(:achievement, game: game))

      expect(pin).to be_valid
    end
  end
end
