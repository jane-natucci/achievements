# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncUserAchievementProgress do
  subject(:call) { described_class.call(user) }

  let(:user) { create(:user) }
  let(:game) { create(:game, steam_app_id: 440) }
  let(:achievement_a) { create(:achievement, game: game, steam_api_name: 'ach_a') }
  let(:achievement_b) { create(:achievement, game: game, steam_api_name: 'ach_b') }
  let(:chain) { create(:chain, game: game) }
  let!(:node_a) { create(:chain_node, chain: chain, achievement: achievement_a) }
  let!(:node_b) { create(:chain_node, chain: chain, achievement: achievement_b) }

  def stub_unlocked(*api_names, unlocktime: 0)
    achievements = api_names.map { |name| { 'apiname' => name, 'achieved' => 1, 'unlocktime' => unlocktime } }
    allow(Steam::UserStats).to receive(:player_achievements).with(440, user.steam_id).and_return('achievements' => achievements)
  end

  context 'when a single achievement is newly unlocked' do
    before { stub_unlocked('ach_a') }

    it 'creates completed progress and awards unlock xp exactly once' do
      expect { call }.to change { user.reload.total_xp }.by(XpRules::ACHIEVEMENT_UNLOCKED)

      progress = UserNodeProgress.find_by(user: user, chain_node: node_a)
      expect(progress.status).to eq('completed')
      expect(user.xp_events.where(reason: 'achievement_unlocked').count).to eq(1)
    end

    it 'does not double-award xp on a second sync' do
      call
      expect { described_class.call(user) }.not_to(change { user.reload.total_xp })
    end
  end

  context 'when every achievement in a chain becomes unlocked' do
    before { stub_unlocked('ach_a', 'ach_b') }

    it 'awards unlock xp for each plus a chain-completion bonus, and records completed_at' do
      expected = (2 * XpRules::ACHIEVEMENT_UNLOCKED) + XpRules::CHAIN_COMPLETED

      expect { call }.to change { user.reload.total_xp }.by(expected)

      progress = UserChainProgress.find_by(user: user, chain: chain)
      expect(progress.completed_at).to be_present
      expect(user.xp_events.where(reason: 'chain_completed').count).to eq(1)
    end

    it 'does not re-award the completion bonus on a later sync' do
      call
      expect { described_class.call(user) }.not_to(change { user.reload.total_xp })
    end
  end

  context 'when an achievement was unlocked long before it was synced (e.g. just added to a chain)' do
    let(:unlocked_at) { 30.days.ago }

    before { stub_unlocked('ach_a', unlocktime: unlocked_at.to_i) }

    it 'backdates both the progress record and the xp event to the real Steam unlock time' do
      call

      progress = UserNodeProgress.find_by(user: user, chain_node: node_a)
      expect(progress.created_at).to be_within(1.second).of(unlocked_at)

      event = user.xp_events.find_by(reason: 'achievement_unlocked')
      expect(event.created_at).to be_within(1.second).of(unlocked_at)
    end

    it "doesn't backdate an already-existing progress record on a later re-sync" do
      call
      first_sync_created_at = UserNodeProgress.find_by(user: user, chain_node: node_a).created_at

      stub_unlocked('ach_a', unlocktime: 60.days.ago.to_i)
      described_class.call(user)

      progress = UserNodeProgress.find_by(user: user, chain_node: node_a)
      expect(progress.created_at).to be_within(1.second).of(first_sync_created_at)
    end
  end

  context 'when an achievement becomes locked again (e.g. Steam data changes)' do
    before { stub_unlocked('ach_a') }

    it 'removes the stale progress record without affecting already-awarded xp' do
      call
      xp_after_first_sync = user.reload.total_xp

      stub_unlocked
      described_class.call(user)

      expect(UserNodeProgress.find_by(user: user, chain_node: node_a)).to be_nil
      expect(user.reload.total_xp).to eq(xp_after_first_sync)
    end
  end

  context 'first-class unlock tracking (for the achievement wall)' do
    let!(:achievement_c) { create(:achievement, game: game, steam_api_name: 'ach_c') }
    let(:unlocked_at) { 10.days.ago }

    it "records an unlock even for an achievement that isn't part of any chain" do
      stub_unlocked('ach_c', unlocktime: unlocked_at.to_i)

      expect { call }.to change { user.user_achievement_unlocks.count }.by(1)

      unlock = user.user_achievement_unlocks.find_by(achievement: achievement_c)
      expect(unlock.unlocked_at).to be_within(1.second).of(unlocked_at)
      expect(unlock.source).to eq('steam')
    end

    it 'also records an unlock for achievements that are part of a chain' do
      stub_unlocked('ach_a', unlocktime: unlocked_at.to_i)

      call

      unlock = user.user_achievement_unlocks.find_by(achievement: achievement_a)
      expect(unlock).to be_present
      expect(unlock.unlocked_at).to be_within(1.second).of(unlocked_at)
    end

    it 'removes the unlock record when the achievement becomes locked again' do
      stub_unlocked('ach_c', unlocktime: unlocked_at.to_i)
      call
      expect(user.user_achievement_unlocks.count).to eq(1)

      stub_unlocked
      described_class.call(user)

      expect(user.user_achievement_unlocks.count).to eq(0)
    end

    it "doesn't touch unlocks belonging to a different user" do
      other_user = create(:user)
      UserAchievementUnlock.create!(user: other_user, achievement: achievement_c, source: 'steam')
      stub_unlocked('ach_c', unlocktime: unlocked_at.to_i)

      call

      expect(other_user.user_achievement_unlocks.count).to eq(1)
    end
  end
end
