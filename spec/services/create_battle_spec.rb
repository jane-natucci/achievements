# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CreateBattle do
  subject(:call) { described_class.call(user: user, chain: chain) }

  let(:user) { create(:user) }
  let(:game) { create(:game) }

  def build_chain(node_count, game:)
    chain = create(:chain, game: game)
    nodes = Array.new(node_count) { create(:chain_node, chain: chain, achievement: create(:achievement, game: game)) }
    nodes.each_cons(2) { |from_node, to_node| create(:chain_edge, chain: chain, from_node: from_node.id, to_node: to_node.id) }
    chain
  end

  context 'with a battle-eligible chain' do
    let(:chain) { build_chain(5, game: game) }

    # Deterministic by default -- CreateBattle's random first-mover coin
    # flip otherwise sometimes seeds an opening AI move that changes hp/zone
    # state before these assertions run. The two tests further down that
    # actually exercise the coin flip override this back to "opponent".
    before { allow_any_instance_of(described_class).to receive(:first_mover).and_return('player') }

    it 'creates a battle with mirrored player and opponent cards' do
      result = call

      expect(result.success?).to be(true)
      battle = result.battle
      expect(battle.user).to eq(user)
      expect(battle.deck_chain).to eq(chain)
      expect(battle.player_hp).to eq(Battle::STARTING_HP)
      expect(battle.opponent_hp).to eq(Battle::STARTING_HP)
      expect(battle.player_cards.size).to eq(5)
      expect(battle.opponent_cards.size).to eq(5)
      expect(battle.player_cards.map { |c| c.achievement_id }.sort).to eq(battle.opponent_cards.map { |c| c.achievement_id }.sort)
    end

    it 'deals the first HAND_SIZE cards to hand, in chain order, and leaves the rest in deck' do
      battle = call.battle

      player_cards = battle.player_cards.sort_by(&:deck_position)
      expect(player_cards.first(described_class::HAND_SIZE).map(&:zone)).to all(eq('hand'))
      expect(player_cards.drop(described_class::HAND_SIZE).map(&:zone)).to all(eq('deck'))
    end

    it 'snapshots hp/dmg from CardStats onto each card' do
      battle = call.battle

      card = battle.player_cards.first
      expected = CardStats.for(card.achievement)
      expect(card.hp_max).to eq(expected.hp)
      expect(card.hp_current).to eq(expected.hp)
      expect(card.dmg).to eq(expected.dmg)
    end

    it 'resolves an opening AI turn if the opponent is picked to go first' do
      allow_any_instance_of(described_class).to receive(:first_mover).and_return('opponent')

      battle = call.battle

      expect(battle.battle_moves.count).to eq(1)
      expect(battle.battle_moves.first.acting_side).to eq('opponent')
      expect(battle.current_turn_side).to eq('player')
    end

    it "doesn't resolve any move if the player is picked to go first" do
      allow_any_instance_of(described_class).to receive(:first_mover).and_return('player')

      battle = call.battle

      expect(battle.battle_moves.count).to eq(0)
      expect(battle.current_turn_side).to eq('player')
    end
  end

  context 'when the chain has no achievements' do
    let(:chain) { create(:chain, game: game) }

    it 'fails without creating a battle' do
      expect { call }.not_to change(Battle, :count)
      expect(call.error).to match(/no achievements/i)
    end
  end

  context 'when the chain is bigger than the battle-eligible limit' do
    let(:chain) { build_chain(Battle::MAX_DECK_SIZE + 1, game: game) }

    it 'fails without creating a battle' do
      expect { call }.not_to change(Battle, :count)
      expect(call.error).to match(/too many/i)
    end
  end
end
