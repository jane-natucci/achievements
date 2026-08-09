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

  def stub_unlocked(*api_names)
    achievements = api_names.map { |name| { 'apiname' => name, 'achieved' => 1, 'unlocktime' => 0 } }
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
end
