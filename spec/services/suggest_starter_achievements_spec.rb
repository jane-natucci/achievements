# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SuggestStarterAchievements do
  subject(:tiers) { described_class.call(game) }

  let(:game) { create(:game, steam_app_id: 440) }

  context 'with plenty of achievements and full percentage data' do
    let!(:achievements) do
      Array.new(9) { |n| create(:achievement, game: game, steam_api_name: "ach_#{n}") }
    end

    before do
      percentages = achievements.each_with_index.map do |achievement, index|
        { 'name' => achievement.steam_api_name, 'percent' => (90 - index * 8).to_s }
      end
      allow(Steam::UserStats).to receive(:achievement_percentages).with(440).and_return(percentages)
    end

    it 'returns 3 tiers of up to 3 candidates each' do
      expect(tiers.size).to eq(3)
      expect(tiers).to all(have_attributes(size: 3))
    end

    it 'orders tiers from most to least commonly unlocked' do
      expect(tiers[0]).to eq(achievements[0..2])
      expect(tiers[1]).to eq(achievements[3..5])
      expect(tiers[2]).to eq(achievements[6..8])
    end

    it 'never repeats an achievement across tiers' do
      flattened = tiers.flatten
      expect(flattened.uniq).to eq(flattened)
    end
  end

  context 'when Steam has no percentage data for some achievements' do
    let!(:known) { create(:achievement, game: game, steam_api_name: 'known') }
    let!(:unknowns) { create_list(:achievement, 5, game: game) }

    before do
      allow(Steam::UserStats).to receive(:achievement_percentages)
        .with(440)
        .and_return([{ 'name' => 'known', 'percent' => '50.0' }])
    end

    it 'still ranks the achievement with known data first' do
      expect(tiers.first).to include(known)
    end
  end

  context 'when the Steam API call fails' do
    let!(:achievements) { create_list(:achievement, 6, game: game) }

    before do
      allow(Steam::UserStats).to receive(:achievement_percentages).and_raise(StandardError, 'boom')
    end

    it 'still returns candidates instead of raising' do
      expect(tiers.flatten.size).to eq(6)
    end
  end

  context 'with very few achievements' do
    let!(:achievements) { create_list(:achievement, 2, game: game) }

    before do
      allow(Steam::UserStats).to receive(:achievement_percentages).and_return([])
    end

    it 'degrades gracefully instead of crashing' do
      expect(tiers.flatten.size).to eq(2)
      expect(tiers.flatten.uniq).to eq(tiers.flatten)
    end
  end

  context 'with no achievements at all' do
    before do
      allow(Steam::UserStats).to receive(:achievement_percentages).and_return([])
    end

    it 'returns 3 empty tiers' do
      expect(tiers).to eq([[], [], []])
    end
  end
end
