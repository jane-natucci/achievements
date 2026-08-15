# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PlaceBattleCard do
  subject(:call) { described_class.call(battle: battle, side: 'player', card: card) }

  let(:battle) { build_battle }
  let(:card) { build_card(battle, side: 'player', zone: 'hand') }

  def build_battle(current_turn_side: 'player')
    Battle.create!(user: create(:user), deck_chain: create(:chain), current_turn_side: current_turn_side)
  end

  def build_card(battle, side:, zone: 'hand', hp: 10, dmg: 5, slot: nil, acted_this_turn: false)
    battle.battle_cards.create!(
      side: side, achievement: create(:achievement), hp_max: hp, hp_current: hp, dmg: dmg, zone: zone, slot: slot,
      deck_position: 0, acted_this_turn: acted_this_turn
    )
  end

  it 'places the card onto the board (first open slot) and marks it acted, without any move or damage' do
    expect(call.success?).to be(true)

    expect(card.reload.zone).to eq('board')
    expect(card.slot).to eq('left')
    expect(card.acted_this_turn?).to be(true)
    expect(battle.reload.battle_moves.count).to eq(0)
  end

  it "marks the side as having placed a card this turn" do
    call

    expect(battle.reload.placed_card_this_turn?('player')).to be(true)
  end

  it 'places into the first open slot when earlier slots are occupied' do
    build_card(battle, side: 'player', zone: 'board', slot: 'left')

    call

    expect(card.reload.slot).to eq('center')
  end

  describe 'validation' do
    it 'rejects when the battle is already over' do
      battle.update!(status: 'won')

      expect(call.success?).to be(false)
      expect(call.error).to match(/already over/i)
    end

    it "rejects when it isn't the side's turn" do
      battle.update!(current_turn_side: 'opponent')

      expect(call.success?).to be(false)
      expect(call.error).to match(/not your turn/i)
    end

    it 'rejects a card not in hand' do
      board_card = build_card(battle, side: 'player', zone: 'board', slot: 'left')

      result = described_class.call(battle: battle, side: 'player', card: board_card)

      expect(result.success?).to be(false)
      expect(result.error).to match(/can't be placed/i)
    end

    it 'rejects a second placement in the same turn' do
      other_hand_card = build_card(battle, side: 'player', zone: 'hand')
      call

      result = described_class.call(battle: battle, side: 'player', card: other_hand_card)

      expect(result.success?).to be(false)
      expect(result.error).to match(/already placed/i)
    end

    it 'rejects placing when the board has no open slot' do
      BattleCard::SLOTS.each { |slot| build_card(battle, side: 'player', zone: 'board', slot: slot) }

      expect(call.success?).to be(false)
      expect(call.error).to match(/slot/i)
    end

    it 'makes no changes when validation fails' do
      battle.update!(current_turn_side: 'opponent')

      expect { call }.not_to(change { battle.reload.attributes })
      expect(card.reload.zone).to eq('hand')
    end
  end
end
