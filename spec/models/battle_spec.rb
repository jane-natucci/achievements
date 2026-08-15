# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Battle do
  def build_battle(current_turn_side: 'player', player_turn_count: 0, opponent_turn_count: 0)
    Battle.create!(
      user: create(:user), deck_chain: create(:chain), current_turn_side: current_turn_side,
      player_turn_count: player_turn_count, opponent_turn_count: opponent_turn_count
    )
  end

  def build_card(battle, side:, zone: 'hand', hp: 10, dmg: 5, slot: nil, acted_this_turn: false)
    battle.battle_cards.create!(
      side: side, achievement: create(:achievement), hp_max: hp, hp_current: hp, dmg: dmg, zone: zone, slot: slot,
      deck_position: 0, acted_this_turn: acted_this_turn
    )
  end

  describe '#start_turn!' do
    it "does not draw on a side's 1st turn" do
      battle = build_battle
      build_card(battle, side: 'player', zone: 'deck')

      battle.start_turn!('player')

      expect(battle.player_cards.none? { |c| c.zone == 'hand' }).to be(true)
    end

    it "draws one card from deck to hand from a side's 2nd turn onward" do
      battle = build_battle(player_turn_count: 1)
      deck_card = build_card(battle, side: 'player', zone: 'deck')

      battle.start_turn!('player')

      expect(deck_card.reload.zone).to eq('hand')
    end

    it "does nothing when that side's deck is already empty" do
      battle = build_battle(player_turn_count: 1)

      expect { battle.start_turn!('player') }.not_to raise_error
    end

    it 'increments the turn counter for the given side only' do
      battle = build_battle

      battle.start_turn!('player')

      expect(battle.player_turn_count).to eq(1)
      expect(battle.opponent_turn_count).to eq(0)
    end

    it "resets that side's acted_this_turn flags" do
      battle = build_battle
      acted_card = build_card(battle, side: 'player', zone: 'board', slot: 'left', acted_this_turn: true)

      battle.start_turn!('player')

      expect(acted_card.reload.acted_this_turn?).to be(false)
    end
  end

  describe '#actionable_cards_for' do
    it 'excludes a card that already acted this turn' do
      battle = build_battle
      build_card(battle, side: 'player', zone: 'board', slot: 'left', acted_this_turn: true)

      expect(battle.actionable_cards_for('player')).to be_empty
    end

    it 'excludes a hand card when the board already holds 3 living cards' do
      battle = build_battle
      BattleCard::SLOTS.each { |slot| build_card(battle, side: 'player', zone: 'board', slot: slot) }
      hand_card = build_card(battle, side: 'player', zone: 'hand')

      expect(battle.actionable_cards_for('player')).not_to include(hand_card)
    end

    it 'includes a hand card again once a board slot frees up (a card died)' do
      battle = build_battle
      build_card(battle, side: 'player', zone: 'board', slot: 'left')
      build_card(battle, side: 'player', zone: 'board', slot: 'center')
      build_card(battle, side: 'player', zone: 'dead', hp: 0, slot: 'right')
      hand_card = build_card(battle, side: 'player', zone: 'hand')

      expect(battle.actionable_cards_for('player')).to include(hand_card)
    end
  end
end
