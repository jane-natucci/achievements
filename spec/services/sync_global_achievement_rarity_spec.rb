# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncGlobalAchievementRarity do
  subject(:call) { described_class.call }

  def stub_percentages(app_id, *entries)
    allow(Steam::UserStats).to receive(:achievement_percentages).with(app_id).and_return(entries)
  end

  it "updates each achievement's global_unlock_pct from Steam, matched by steam_api_name" do
    game = create(:game, steam_app_id: 440)
    common = create(:achievement, game: game, steam_api_name: 'ACH_COMMON')
    rare = create(:achievement, game: game, steam_api_name: 'ACH_RARE')
    stub_percentages(440, { 'name' => 'ACH_COMMON', 'percent' => 68.9 }, { 'name' => 'ACH_RARE', 'percent' => 2.1 })

    call

    expect(common.reload.global_unlock_pct).to eq(68.9)
    expect(rare.reload.global_unlock_pct).to eq(2.1)
  end

  it 'skips games with no steam_app_id' do
    game = create(:game, steam_app_id: nil)
    achievement = create(:achievement, game: game)

    expect(Steam::UserStats).not_to receive(:achievement_percentages)
    call

    expect(achievement.reload.global_unlock_pct).to be_nil
  end

  it "leaves an achievement's global_unlock_pct untouched when Steam has no matching entry for it" do
    game = create(:game, steam_app_id: 440)
    achievement = create(:achievement, game: game, steam_api_name: 'ACH_UNKNOWN', global_unlock_pct: 33.0)
    stub_percentages(440, { 'name' => 'ACH_SOMETHING_ELSE', 'percent' => 10.0 })

    call

    expect(achievement.reload.global_unlock_pct).to eq(33.0)
  end

  it 'keeps syncing other games when one game errors out' do
    broken_game = create(:game, steam_app_id: 1)
    ok_game = create(:game, steam_app_id: 2)
    ok_achievement = create(:achievement, game: ok_game, steam_api_name: 'ACH_OK')
    allow(Steam::UserStats).to receive(:achievement_percentages).with(1).and_raise(StandardError, 'boom')
    stub_percentages(2, { 'name' => 'ACH_OK', 'percent' => 5.0 })

    expect { call }.not_to raise_error
    expect(ok_achievement.reload.global_unlock_pct).to eq(5.0)
  end
end
