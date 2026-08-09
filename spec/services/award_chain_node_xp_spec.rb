# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AwardChainNodeXp do
  subject(:call) { described_class.call(chain, chain_nodes) }

  let(:user) { create(:user) }
  let(:chain) { create(:chain, creator: user) }

  context 'with a node that has no note' do
    let(:chain_nodes) { [create(:chain_node, chain: chain, note: nil)] }

    it 'awards only the added-to-chain bonus' do
      expect { call }.to change { user.reload.total_xp }.by(XpRules::ACHIEVEMENT_ADDED_TO_CHAIN)
      expect(user.xp_events.pluck(:reason)).to eq(['achievement_added'])
    end
  end

  context 'with a node that has a note' do
    let(:chain_nodes) { [create(:chain_node, chain: chain, note: 'context')] }

    it 'awards both the added-to-chain and note bonuses' do
      expected = XpRules::ACHIEVEMENT_ADDED_TO_CHAIN + XpRules::ACHIEVEMENT_NOTE_BONUS
      expect { call }.to change { user.reload.total_xp }.by(expected)
      expect(user.xp_events.pluck(:reason)).to contain_exactly('achievement_added', 'achievement_note')
    end
  end

  context 'with an empty list of nodes' do
    let(:chain_nodes) { [] }

    it 'awards nothing' do
      expect(call).to eq([])
    end
  end

  context 'when the chain has no creator' do
    let(:chain) { create(:chain, creator: nil) }
    let(:chain_nodes) { [create(:chain_node, chain: chain)] }

    it 'awards nothing and returns an empty array' do
      expect(call).to eq([])
    end
  end
end
