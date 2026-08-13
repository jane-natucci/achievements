# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResolveBattleTurn do
  subject(:call) do
    described_class.call(battle: battle, side: side, acting_card: acting_card, target: target, stance: stance, slot: slot)
  end

  let(:battle) { build_battle }
  let(:side) { 'player' }
  let(:stance) { 'neutral' }
  let(:slot) { 'left' }
  let(:target) { :player }
  let(:acting_card) { battle.player_cards.first }

  def build_battle(current_turn_side: 'player')
    Battle.create!(user: create(:user), deck_chain: create(:chain), current_turn_side: current_turn_side)
  end

  def build_card(battle, side:, zone: 'hand', hp: 10, dmg: 5, slot: nil)
    battle.battle_cards.create!(
      side: side, achievement: create(:achievement), hp_max: hp, hp_current: hp, dmg: dmg, zone: zone, slot: slot, deck_position: 0
    )
  end

  before do
    build_card(battle, side: 'player', zone: 'hand', hp: 10, dmg: 5)
    build_card(battle, side: 'opponent', zone: 'board', hp: 10, dmg: 5, slot: 'left')
  end

  it 'places a hand card onto the board and attacks the opponent directly' do
    expect(call.success?).to be(true)

    expect(acting_card.reload.zone).to eq('board')
    expect(acting_card.slot).to eq('left')
    expect(battle.reload.opponent_hp).to eq(Battle::STARTING_HP - 5)
  end

  it 'records a BattleMove with the right details' do
    call

    move = battle.battle_moves.last
    expect(move.turn_number).to eq(1)
    expect(move.acting_side).to eq('player')
    expect(move.acting_battle_card).to eq(acting_card)
    expect(move.target_type).to eq('player')
    expect(move.damage_dealt).to eq(5)
    expect(move.target_hp_after).to eq(Battle::STARTING_HP - 5)
    expect(move.stance_used).to eq('neutral')
  end

  it 'advances the turn to the other side' do
    call

    expect(battle.reload.current_turn_side).to eq('opponent')
  end

  it "doesn't require a slot for a card already on the board" do
    board_card = build_card(battle, side: 'player', zone: 'board', hp: 10, dmg: 5, slot: 'center')

    result = described_class.call(battle: battle, side: 'player', acting_card: board_card, target: :player, stance: 'neutral', slot: nil)

    expect(result.success?).to be(true)
  end

  describe 'stance damage multipliers' do
    it 'attack stance deals +25% damage, rounded' do
      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: :player, stance: 'attack', slot: 'left')

      expect(result.move.damage_dealt).to eq((5 * 1.25).round)
    end

    it 'defense stance deals -25% damage, rounded' do
      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: :player, stance: 'defense', slot: 'left')

      expect(result.move.damage_dealt).to eq((5 * 0.75).round)
    end

    it "doesn't apply any stance modifier to the defending side (always neutral unless it's their own turn)" do
      target_card = battle.opponent_cards.first

      described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: target_card, stance: 'attack', slot: 'left')

      # attacker in Attack stance: 5 * 1.25 = 6.25 -> rounds to 6, regardless of the target's own state
      expect(target_card.reload.hp_current).to eq(10 - 6)
    end
  end

  describe 'attacking a card' do
    let(:target) { battle.opponent_cards.first }

    it 'reduces the target hp_current' do
      call

      expect(target.reload.hp_current).to eq(5)
    end

    it 'kills the target at 0 hp and marks its zone dead' do
      weak_target = build_card(battle, side: 'opponent', zone: 'board', hp: 3, dmg: 1, slot: 'center')

      described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: weak_target, stance: 'neutral', slot: 'left')

      expect(weak_target.reload.hp_current).to eq(0)
      expect(weak_target.zone).to eq('dead')
    end

    it "never drops a card's hp below 0" do
      weak_target = build_card(battle, side: 'opponent', zone: 'board', hp: 2, dmg: 1, slot: 'center')

      described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: weak_target, stance: 'neutral', slot: 'left')

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

      described_class.call(battle: battle, side: 'opponent', acting_card: opponent_card, target: :player, stance: 'neutral', slot: nil)

      expect(battle.reload.status).to eq('lost')
    end

    it "doesn't advance the turn once the battle is over" do
      battle.update!(opponent_hp: 4)

      call

      expect(battle.reload.current_turn_side).to eq('player')
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

      result = described_class.call(battle: battle, side: 'player', acting_card: dead_card, target: :player, stance: 'neutral', slot: nil)

      expect(result.success?).to be(false)
    end

    it 'rejects an unknown stance' do
      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: :player, stance: 'berserk', slot: 'left')

      expect(result.success?).to be(false)
      expect(result.error).to match(/stance/i)
    end

    it 'rejects placing a hand card without a slot' do
      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: :player, stance: 'neutral', slot: nil)

      expect(result.success?).to be(false)
      expect(result.error).to match(/slot/i)
    end

    it 'rejects attacking a dead card' do
      dead_target = build_card(battle, side: 'opponent', zone: 'dead', hp: 0, dmg: 5, slot: 'center')

      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: dead_target, stance: 'neutral', slot: 'left')

      expect(result.success?).to be(false)
      expect(result.error).to match(/target/i)
    end

    it "rejects attacking your own side's card" do
      own_card = build_card(battle, side: 'player', zone: 'board', hp: 10, dmg: 5, slot: 'center')

      result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: own_card, stance: 'neutral', slot: 'left')

      expect(result.success?).to be(false)
      expect(result.error).to match(/target/i)
    end

    it "rejects attacking an enemy card that isn't on the board yet (hand/deck aren't valid targets)" do
      hand_target = build_card(battle, side: 'opponent', zone: 'hand', hp: 10, dmg: 5)
      deck_target = build_card(battle, side: 'opponent', zone: 'deck', hp: 10, dmg: 5)

      [hand_target, deck_target].each do |target|
        result = described_class.call(battle: battle, side: 'player', acting_card: acting_card, target: target, stance: 'neutral', slot: 'left')

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
