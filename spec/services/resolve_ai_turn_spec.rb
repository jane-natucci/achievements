# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResolveAiTurn do
  subject(:call) { described_class.call(battle: battle) }

  let(:battle) { build_battle }

  def build_battle(current_turn_side: 'opponent')
    Battle.create!(user: create(:user), deck_chain: create(:chain), current_turn_side: current_turn_side)
  end

  def build_card(battle, side:, zone: 'hand', hp: 10, dmg: 5, slot: nil)
    battle.battle_cards.create!(
      side: side, achievement: create(:achievement), hp_max: hp, hp_current: hp, dmg: dmg, zone: zone, slot: slot, deck_position: 0
    )
  end

  context 'when the opponent has several actionable cards' do
    before do
      3.times { build_card(battle, side: 'opponent', zone: 'hand', dmg: 5) }
      build_card(battle, side: 'player', zone: 'board', hp: 100, slot: 'left')
    end

    it 'resolves one move per actionable card, all acting for the opponent' do
      result = call

      expect(result.moves.size).to eq(3)
      expect(result.moves.map(&:acting_side)).to all(eq('opponent'))
    end

    it 'yields the battle state and move once per resolved action' do
      yielded = []

      described_class.call(battle: battle) { |b, move| yielded << [b, move] }

      expect(yielded.size).to eq(3)
      expect(yielded.map { |(_, move)| move.acting_side }).to all(eq('opponent'))
    end

    it "hands control back to the player once the opponent's cards are exhausted" do
      result = call

      expect(result.battle.current_turn_side).to eq('player')
      expect(result.battle.player_turn_count).to eq(1)
    end
  end

  context 'when the battle ends mid-loop' do
    before do
      3.times { build_card(battle, side: 'opponent', zone: 'hand', dmg: 5) }
      battle.update!(player_hp: 3)
    end

    it 'stops resolving further opponent actions' do
      result = call

      expect(result.moves.size).to eq(1)
      expect(result.battle.status).to eq('lost')
    end

    it 'does not hand control back to the player' do
      result = call

      expect(result.battle.current_turn_side).to eq('opponent')
    end
  end

  context 'when the opponent has no actionable cards at all' do
    before { build_card(battle, side: 'player', zone: 'hand') }

    it 'resolves zero moves and still hands control back to the player' do
      result = call

      expect(result.moves).to eq([])
      expect(result.battle.current_turn_side).to eq('player')
    end
  end
end
