# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EndBattleTurn do
  subject(:call) { described_class.call(battle: battle, side: 'player') }

  let(:battle) { build_battle }

  def build_battle(current_turn_side: 'player')
    Battle.create!(user: create(:user), deck_chain: create(:chain), current_turn_side: current_turn_side)
  end

  def build_card(battle, side:, zone: 'hand', hp: 10, dmg: 5, slot: nil, acted_this_turn: false)
    battle.battle_cards.create!(
      side: side, achievement: create(:achievement), hp_max: hp, hp_current: hp, dmg: dmg, zone: zone, slot: slot,
      deck_position: 0, acted_this_turn: acted_this_turn
    )
  end

  describe 'validation' do
    it 'rejects ending a turn when the battle is already over' do
      battle.update!(status: 'won')

      expect(call.success?).to be(false)
      expect(call.error).to match(/already over/i)
    end

    it "rejects ending a turn that isn't the given side's" do
      battle.update!(current_turn_side: 'opponent')

      expect(call.success?).to be(false)
      expect(call.error).to match(/not your turn/i)
    end
  end

  context 'when the opponent has actionable cards' do
    before do
      build_card(battle, side: 'player', zone: 'board', acted_this_turn: true, slot: 'left')
      2.times { build_card(battle, side: 'opponent', zone: 'hand', dmg: 3) }
      build_card(battle, side: 'player', zone: 'board', hp: 100, slot: 'center')
    end

    it "flips to and starts the opponent's turn" do
      call

      expect(battle.reload.opponent_turn_count).to eq(1)
    end

    it "runs the opponent's entire turn and hands control back to the player" do
      result = call

      expect(result.success?).to be(true)
      expect(result.moves.size).to eq(2)
      expect(result.moves).to all(have_attributes(acting_side: 'opponent'))
      expect(result.battle.current_turn_side).to eq('player')
      expect(result.battle.player_turn_count).to eq(1)
    end

    it 'resets the acting side (player) cards for their next turn' do
      call

      player_board_card = battle.player_cards.find { |c| c.zone == 'board' }
      expect(player_board_card.reload.acted_this_turn?).to be(false)
    end

    it 'yields one snapshot per opponent action via the given block' do
      yielded_moves = []

      described_class.call(battle: battle, side: 'player') { |_battle, move| yielded_moves << move }

      expect(yielded_moves.size).to eq(2)
    end
  end

  context "when the opponent's whole turn ends the battle" do
    before do
      build_card(battle, side: 'opponent', zone: 'hand', dmg: 20)
      battle.update!(player_hp: 5)
    end

    it 'does not hand control back to the player' do
      result = call

      expect(result.battle.status).to eq('lost')
      expect(result.battle.current_turn_side).to eq('opponent')
    end
  end
end
