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

    it 'creates a battle, dealing the player their own chain' do
      result = call

      expect(result.success?).to be(true)
      battle = result.battle
      expect(battle.user).to eq(user)
      expect(battle.deck_chain).to eq(chain)
      expect(battle.player_hp).to eq(Battle::STARTING_HP)
      expect(battle.opponent_hp).to eq(Battle::STARTING_HP)
      expect(battle.player_cards.size).to eq(5)
      expect(battle.player_cards.map(&:achievement_id).sort).to eq(chain.nodes_in_order.map { |n| n.achievement.id }.sort)
    end

    it "mirrors the player's own chain for the opponent when no other eligible chain exists yet" do
      battle = call.battle

      expect(battle.opponent_cards.map(&:achievement_id).sort).to eq(battle.player_cards.map(&:achievement_id).sort)
    end

    it "battles against a different chain's cards -- even one made by someone else -- when another eligible chain exists" do
      other_chain = build_chain(4, game: game)

      battle = call.battle

      expect(battle.opponent_cards.size).to eq(4)
      expect(battle.opponent_cards.map(&:achievement_id).sort).to eq(other_chain.nodes_in_order.map { |n| n.achievement.id }.sort)
      expect(battle.opponent_cards.map(&:achievement_id).sort).not_to eq(battle.player_cards.map(&:achievement_id).sort)
    end

    it 'rejects starting a battle when the user already has one active' do
      Battle.create!(user: user, deck_chain: chain, current_turn_side: 'player', status: 'active')

      expect { call }.not_to change(Battle, :count)
      expect(call.error).to match(/already have a battle in progress/i)
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

    it "resolves the opponent's entire opening turn if they're picked to go first" do
      allow_any_instance_of(described_class).to receive(:first_mover).and_return('opponent')

      battle = call.battle

      # Only one placement is allowed per side per turn, and a freshly
      # placed card can't also attack the turn it's placed -- so an
      # opening turn (0 board cards yet) resolves exactly one placement
      # and no attacks/moves at all.
      expect(battle.battle_moves.count).to eq(0)
      expect(battle.opponent_cards.count { |c| c.zone == 'board' }).to eq(1)
      expect(battle.current_turn_side).to eq('player')
      expect(battle.active?).to be(true)
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
