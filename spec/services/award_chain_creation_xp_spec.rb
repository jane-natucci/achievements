# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AwardChainCreationXp do
  subject(:call) { described_class.call(chain) }

  let(:user) { create(:user) }
  let(:game) { create(:game) }
  let(:chain) { create(:chain, game: game, creator: user, description: description) }
  let(:description) { nil }

  context 'with a bare chain and no nodes' do
    it 'only awards the base chain-created xp' do
      expect { call }.to change { user.reload.total_xp }.by(XpRules::CHAIN_CREATED)
      expect(user.xp_events.pluck(:reason)).to eq(['chain_created'])
    end
  end

  context 'with a description' do
    let(:description) { 'A fine chain indeed.' }

    it 'also awards the description bonus' do
      expect { call }.to change { user.reload.total_xp }.by(XpRules::CHAIN_CREATED + XpRules::CHAIN_DESCRIPTION_BONUS)
      expect(user.xp_events.pluck(:reason)).to contain_exactly('chain_created', 'chain_description')
    end
  end

  context 'with achievements, some with notes' do
    before do
      create(:chain_node, chain: chain, note: 'a note')
      create(:chain_node, chain: chain, note: nil)
      create(:chain_node, chain: chain, note: '')
    end

    it 'awards per-achievement and per-note xp' do
      expected = XpRules::CHAIN_CREATED + (3 * XpRules::ACHIEVEMENT_ADDED_TO_CHAIN) + (1 * XpRules::ACHIEVEMENT_NOTE_BONUS)

      expect { call }.to change { user.reload.total_xp }.by(expected)

      reasons = user.xp_events.pluck(:reason)
      expect(reasons.count('achievement_added')).to eq(3)
      expect(reasons.count('achievement_note')).to eq(1)
    end
  end

  context 'when the chain has no creator' do
    let(:chain) { create(:chain, game: game, creator: nil) }

    it 'awards nothing and returns an empty array' do
      expect(call).to eq([])
    end
  end
end
