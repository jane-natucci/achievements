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

  context 'when only a hand card is actionable' do
    before { build_card(battle, side: 'opponent', zone: 'hand') }

    it 'places it onto the board rather than attacking (a placed card cannot also attack this turn)' do
      card = battle.opponent_cards.first

      result = call

      expect(result.success?).to be(true)
      expect(result.move).to be_nil
      expect(card.reload.zone).to eq('board')
      expect(BattleCard::SLOTS).to include(card.slot)
      expect(card.acted_this_turn?).to be(true)
    end
  end

  context 'with an actionable board card' do
    before do
      build_card(battle, side: 'opponent', zone: 'board', slot: 'left')
      build_card(battle, side: 'player', zone: 'board', slot: 'left')
    end

    it 'resolves a valid opponent attack' do
      result = call

      expect(result.success?).to be(true)
      expect(result.move.acting_side).to eq('opponent')
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

  context "when the opponent's remaining board damage this turn adds up to lethal" do
    before do
      build_card(battle, side: 'opponent', zone: 'board', slot: 'left', dmg: 5)
      build_card(battle, side: 'opponent', zone: 'board', slot: 'center', dmg: 5)
      build_card(battle, side: 'player', zone: 'board', slot: 'left', hp: 100)
      battle.update!(player_hp: 8)
    end

    it 'goes for the player directly instead of trading with a card at random' do
      result = call

      expect(result.move.target_type).to eq('player')
    end
  end

  context "when the opponent's remaining board damage this turn falls short of lethal" do
    before do
      build_card(battle, side: 'opponent', zone: 'board', slot: 'left', dmg: 5)
      # dmg: 0 -- a card-target hit retaliates (see ResolveBattleTurn), and
      # a real retaliation dmg would eventually kill the opponent's one
      # card across 20 iterations, which is incidental to what this test
      # is actually checking.
      build_card(battle, side: 'player', zone: 'board', slot: 'left', hp: 100, dmg: 0)
      # High enough that even 20 rounds of nothing but face damage can't
      # end the battle mid-loop and start returning "already over" errors.
      battle.update!(player_hp: 500)
    end

    it 'can still trade with a card (not forced to go face every turn)' do
      results = 20.times.map { described_class.call(battle: battle.tap { |b| b.opponent_cards.first.update!(acted_this_turn: false) }) }

      expect(results.map { |r| r.move.target_type }).to include('card')
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

      next unless result.move&.target_type == 'card'

      expect(result.move.target_battle_card_id).to eq(board_card.id)
    end

    expect(hidden_card_ids).not_to be_empty
  end
end
