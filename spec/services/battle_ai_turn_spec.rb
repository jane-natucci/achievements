# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BattleAiTurn do
  subject(:call) { described_class.call(battle: battle) }

  def build_battle(current_turn_side: 'opponent')
    Battle.create!(user: create(:user), deck_chain: create(:chain), current_turn_side: current_turn_side)
  end

  def build_card(battle, side:, zone: 'hand', hp: 10, dmg: 5, slot: nil)
    battle.battle_cards.create!(
      side: side, achievement: create(:achievement), hp_max: hp, hp_current: hp, dmg: dmg, zone: zone, slot: slot, deck_position: 0
    )
  end

  let(:battle) { build_battle }

  context 'with actionable opponent cards' do
    before do
      build_card(battle, side: 'opponent', zone: 'hand')
      build_card(battle, side: 'player', zone: 'board', slot: 'left')
    end

    it 'resolves a valid opponent move' do
      result = call

      expect(result.success?).to be(true)
      expect(result.move.acting_side).to eq('opponent')
      expect(%w[attack defense neutral]).to include(result.move.stance_used)
    end

    it 'places a hand card onto the board as part of acting' do
      card = battle.opponent_cards.first

      call

      expect(card.reload.zone).to eq('board')
      expect(BattleCard::SLOTS).to include(card.slot)
    end

    it 'only ever targets a player-side board card or the player directly' do
      result = call

      if result.move.target_type == 'card'
        expect(result.move.target_battle_card.side).to eq('player')
        expect(result.move.target_battle_card.zone).to eq('board')
      else
        expect(result.move.target_type).to eq('player')
      end
    end

    it 'attacks the player directly when no player cards are on the board' do
      battle.player_cards.first.update!(zone: 'dead', hp_current: 0)

      result = call

      expect(result.move.target_type).to eq('player')
    end
  end

  context 'when the opponent has no actionable cards' do
    it 'returns an error rather than raising' do
      result = call

      expect(result.success?).to be(false)
      expect(result.error).to be_present
    end
  end

  it "never targets a player card still in hand/deck, even though it's technically alive" do
    hidden_card_ids = []

    20.times do
      fresh_battle = build_battle
      board_card = build_card(fresh_battle, side: 'player', zone: 'board', slot: 'left')
      hidden_card = build_card(fresh_battle, side: 'player', zone: 'hand')
      hidden_card_ids << hidden_card.id
      build_card(fresh_battle, side: 'opponent', zone: 'board', slot: 'left')

      result = described_class.call(battle: fresh_battle)

      next unless result.move.target_type == 'card'

      expect(result.move.target_battle_card_id).to eq(board_card.id)
    end

    expect(hidden_card_ids).not_to be_empty
  end
end
