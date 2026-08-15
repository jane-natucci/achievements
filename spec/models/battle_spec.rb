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
    it 'does not draw while the hand still has a card in it' do
      battle = build_battle
      build_card(battle, side: 'player', zone: 'hand')
      deck_card = build_card(battle, side: 'player', zone: 'deck')

      battle.start_turn!('player')

      expect(deck_card.reload.zone).to eq('deck')
    end

    it 'refills the hand up to HAND_REFILL_SIZE cards once it runs completely empty' do
      battle = build_battle
      deck_cards = Array.new(described_class::HAND_REFILL_SIZE) { build_card(battle, side: 'player', zone: 'deck') }

      battle.start_turn!('player')

      expect(deck_cards.map { |card| card.reload.zone }).to all(eq('hand'))
    end

    it "draws as many as are actually available when refilling an empty hand" do
      battle = build_battle
      deck_card = build_card(battle, side: 'player', zone: 'deck')

      expect { battle.start_turn!('player') }.not_to raise_error
      expect(deck_card.reload.zone).to eq('hand')
    end

    it "does nothing when that side's hand, deck, and dead pool are all empty" do
      battle = build_battle

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

    it "resets that side's one-placement-per-turn budget" do
      battle = build_battle
      battle.update!(player_placed_card_this_turn: true)

      battle.start_turn!('player')

      expect(battle.placed_card_this_turn?('player')).to be(false)
    end
  end

  describe '#draw_card!' do
    it 'draws the next deck card when the deck has one' do
      battle = build_battle
      deck_card = build_card(battle, side: 'player', zone: 'deck')

      battle.draw_card!('player')

      expect(deck_card.reload.zone).to eq('hand')
    end

    it "reshuffles this side's own dead cards back into the deck, revived at full hp with a clean acted flag, when the deck is empty" do
      battle = build_battle
      dead_card = build_card(battle, side: 'player', zone: 'dead', hp: 10, acted_this_turn: true)
      dead_card.update!(hp_current: 0)

      battle.draw_card!('player')

      expect(dead_card.reload.zone).to eq('hand')
      expect(dead_card.hp_current).to eq(10)
      expect(dead_card.acted_this_turn?).to be(false)
    end

    it "does not reshuffle the other side's dead cards" do
      battle = build_battle
      opponent_dead = build_card(battle, side: 'opponent', zone: 'dead', hp: 10)
      opponent_dead.update!(hp_current: 0)

      battle.draw_card!('player')

      expect(opponent_dead.reload.zone).to eq('dead')
    end

    it 'does nothing when there is nothing to draw or reshuffle at all' do
      battle = build_battle

      expect { battle.draw_card!('player') }.not_to raise_error
    end

    it "prevents a side from ever running permanently out of actionable cards -- the stuck-battle bug this fixes" do
      battle = build_battle
      dead_card = build_card(battle, side: 'player', zone: 'dead', hp: 10, dmg: 5)
      dead_card.update!(hp_current: 0)
      expect(battle.actionable_cards_for('player')).to be_empty

      battle.start_turn!('player')

      expect(battle.actionable_cards_for('player')).not_to be_empty
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

    it 'excludes every hand card once this side has already placed one this turn' do
      battle = build_battle
      battle.update!(player_placed_card_this_turn: true)
      hand_card_a = build_card(battle, side: 'player', zone: 'hand')
      hand_card_b = build_card(battle, side: 'player', zone: 'hand')

      expect(battle.actionable_cards_for('player')).not_to include(hand_card_a, hand_card_b)
    end

    it "does not exclude the other side's hand cards" do
      battle = build_battle
      battle.update!(player_placed_card_this_turn: true)
      opponent_hand_card = build_card(battle, side: 'opponent', zone: 'hand')

      expect(battle.actionable_cards_for('opponent')).to include(opponent_hand_card)
    end
  end

  describe '#actionable?' do
    it 'is true for an alive board card that has not acted this turn' do
      battle = build_battle
      card = build_card(battle, side: 'player', zone: 'board', slot: 'left')

      expect(battle.actionable?(card)).to be(true)
    end

    it 'is false for a dead board card' do
      battle = build_battle
      card = build_card(battle, side: 'player', zone: 'dead', hp: 0, slot: 'left')

      expect(battle.actionable?(card)).to be(false)
    end

    it 'is false for a hand card once its side has placed a card this turn' do
      battle = build_battle
      battle.update!(player_placed_card_this_turn: true)
      card = build_card(battle, side: 'player', zone: 'hand')

      expect(battle.actionable?(card)).to be(false)
    end

    it 'is false for a card still in the deck' do
      battle = build_battle
      card = build_card(battle, side: 'player', zone: 'deck')

      expect(battle.actionable?(card)).to be(false)
    end
  end

  describe '#mark_card_placed!' do
    it 'sets the placed flag for the given side only' do
      battle = build_battle

      battle.mark_card_placed!('player')

      expect(battle.placed_card_this_turn?('player')).to be(true)
      expect(battle.placed_card_this_turn?('opponent')).to be(false)
    end
  end

  describe '#open_slot?' do
    it 'is true when the board has fewer than 3 cards' do
      battle = build_battle
      build_card(battle, side: 'player', zone: 'board', slot: 'left')

      expect(battle.open_slot?('player')).to be(true)
    end

    it 'is false when all 3 slots are occupied by living cards' do
      battle = build_battle
      BattleCard::SLOTS.each { |slot| build_card(battle, side: 'player', zone: 'board', slot: slot) }

      expect(battle.open_slot?('player')).to be(false)
    end
  end
end
