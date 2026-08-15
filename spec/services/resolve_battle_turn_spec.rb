# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResolveBattleTurn do
  subject(:call) do
    described_class.call(battle: battle, side: side, acting_card: acting_card, target: target)
  end

  let(:battle) { build_battle }
  let(:side) { 'player' }
  let(:target) { :player }
  let(:acting_card) { build_card(battle, side: 'player', zone: 'board', hp: 10, dmg: 5, slot: 'left') }

  def build_battle(current_turn_side: 'player')
    Battle.create!(user: create(:user), deck_chain: create(:chain), current_turn_side: current_turn_side)
  end

  def build_card(battle, side:, zone: 'hand', hp: 10, dmg: 5, slot: nil, acted_this_turn: false)
    battle.battle_cards.create!(
      side: side, achievement: create(:achievement), hp_max: hp, hp_current: hp, dmg: dmg, zone: zone, slot: slot,
      deck_position: 0, acted_this_turn: acted_this_turn
    )
  end

  before do
    build_card(battle, side: 'opponent', zone: 'board', hp: 10, dmg: 5, slot: 'left')
  end

  it 'attacks the opponent directly for the card\'s flat damage' do
    result = call

    expect(result.success?).to be(true)
    expect(battle.reload.opponent_hp).to eq(Battle::STARTING_HP - 5)
  end

  it 'exposes the acting card on the result regardless of the move' do
    expect(call.card).to eq(acting_card)
  end

  it 'records a BattleMove with the right details' do
    call

    move = battle.battle_moves.last
    expect(move.move_number).to eq(1)
    expect(move.acting_side).to eq('player')
    expect(move.acting_battle_card).to eq(acting_card)
    expect(move.target_type).to eq('player')
    expect(move.damage_dealt).to eq(5)
    expect(move.target_hp_after).to eq(Battle::STARTING_HP - 5)
  end

  it 'marks the acting card as having acted this turn, but does not change whose turn it is' do
    call

    expect(acting_card.reload.acted_this_turn?).to be(true)
    expect(battle.reload.current_turn_side).to eq('player')
  end

  describe 'attacking a card' do
    let(:target) { battle.opponent_cards.first }

    it 'reduces the target hp_current by the flat card damage' do
      call

      expect(target.reload.hp_current).to eq(5)
    end

    it 'kills the target at 0 hp and marks its zone dead' do
      weak_target = build_card(battle, side: 'opponent', zone: 'board', hp: 3, dmg: 1, slot: 'center')

      described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: weak_target)

      expect(weak_target.reload.hp_current).to eq(0)
      expect(weak_target.zone).to eq('dead')
    end

    it "never drops a card's hp below 0" do
      weak_target = build_card(battle, side: 'opponent', zone: 'board', hp: 2, dmg: 1, slot: 'center')

      described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: weak_target)

      expect(weak_target.reload.hp_current).to eq(0)
    end
  end

  describe 'win/loss detection' do
    it 'marks the battle won when opponent hp reaches 0' do
      battle.update!(opponent_hp: 4)

      call

      expect(battle.reload.status).to eq('won')
    end

    it 'marks the battle lost when player hp reaches 0' do
      battle.update!(player_hp: 4, current_turn_side: 'opponent')
      opponent_card = battle.opponent_cards.first

      described_class.call(battle: battle, side: 'opponent', acting_card: opponent_card, target: :player)

      expect(battle.reload.status).to eq('lost')
    end
  end

  describe 'validation' do
    it 'rejects a turn when the battle is already over' do
      battle.update!(status: 'won')

      expect(call.success?).to be(false)
      expect(call.error).to match(/already over/i)
    end

    it "rejects a turn when it isn't that side's turn" do
      battle.update!(current_turn_side: 'opponent')

      expect(call.success?).to be(false)
      expect(call.error).to match(/not your turn/i)
    end

    it "rejects a dead card acting" do
      dead_card = build_card(battle, side: 'player', zone: 'dead', hp: 0, dmg: 5, slot: 'center')

      result = described_class.call(battle: battle, side: 'player', acting_card: dead_card, target: :player)

      expect(result.success?).to be(false)
    end

    it "rejects a hand card acting -- it must be placed first (see PlaceBattleCard)" do
      hand_card = build_card(battle, side: 'player', zone: 'hand')

      result = described_class.call(battle: battle, side: 'player', acting_card: hand_card, target: :player)

      expect(result.success?).to be(false)
      expect(result.error).to match(/can't act/i)
    end

    it 'rejects a card that has already acted this turn' do
      acting_card.update!(acted_this_turn: true)

      expect(call.success?).to be(false)
      expect(call.error).to match(/already acted/i)
    end

    it 'rejects attacking a dead card' do
      dead_target = build_card(battle, side: 'opponent', zone: 'dead', hp: 0, dmg: 5, slot: 'center')

      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: dead_target)

      expect(result.success?).to be(false)
      expect(result.error).to match(/target/i)
    end

    it "rejects attacking your own side's card" do
      own_card = build_card(battle, side: 'player', zone: 'board', hp: 10, dmg: 5, slot: 'center')

      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: own_card)

      expect(result.success?).to be(false)
      expect(result.error).to match(/target/i)
    end

    it "rejects attacking an enemy card that isn't on the board yet (hand/deck aren't valid targets)" do
      hand_target = build_card(battle, side: 'opponent', zone: 'hand', hp: 10, dmg: 5)
      deck_target = build_card(battle, side: 'opponent', zone: 'deck', hp: 10, dmg: 5)

      [hand_target, deck_target].each do |target|
        result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: target)

        expect(result.success?).to be(false)
        expect(result.error).to match(/target/i)
      end
    end

    it 'makes no changes when validation fails' do
      battle.update!(current_turn_side: 'opponent')

      expect { call }.not_to(change { battle.reload.attributes })
      expect(battle.battle_moves.count).to eq(0)
    end
  end
end
