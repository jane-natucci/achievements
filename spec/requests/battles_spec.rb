# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Battles', type: :request do
  def sign_in(user)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    post '/achievements/login', params: { profile_url: user.steam_id }
  end

  def build_chain(node_count, game:, creator: nil)
    chain = create(:chain, game: game, creator: creator)
    nodes = Array.new(node_count) { create(:chain_node, chain: chain, achievement: create(:achievement, game: game)) }
    nodes.each_cons(2) { |from_node, to_node| create(:chain_edge, chain: chain, from_node: from_node.id, to_node: to_node.id) }
    chain
  end

  describe 'GET /achievements/battles/new' do
    it 'redirects a logged-out visitor to log in' do
      get new_battle_path

      expect(response).to redirect_to('/achievements/login/')
    end

    it 'only lists the current user\'s own battle-eligible chains' do
      user = create(:user)
      sign_in(user)
      game = create(:game)
      eligible = build_chain(3, game: game, creator: user)
      too_big = build_chain(Battle::MAX_DECK_SIZE + 1, game: game, creator: user)
      someone_elses = build_chain(3, game: game, creator: create(:user))

      get new_battle_path

      expect(response.body).to include(eligible.title)
      expect(response.body).not_to include(too_big.title)
      expect(response.body).not_to include(someone_elses.title)
    end
  end

  describe 'POST /achievements/battles' do
    it 'starts a battle and redirects to it' do
      user = create(:user)
      sign_in(user)
      chain = build_chain(3, game: create(:game), creator: user)

      expect {
        post battles_path, params: { chain_id: chain.id }
      }.to change(Battle, :count).by(1)

      expect(response).to redirect_to(battle_path(Battle.last))
    end

    it 'redirects back with an error for an ineligible chain' do
      user = create(:user)
      sign_in(user)
      chain = build_chain(Battle::MAX_DECK_SIZE + 1, game: create(:game), creator: user)

      expect {
        post battles_path, params: { chain_id: chain.id }
      }.not_to change(Battle, :count)

      expect(response).to redirect_to(new_battle_path)
    end
  end

  describe 'GET /achievements/battles/:id' do
    it "blocks viewing someone else's battle" do
      owner = create(:user)
      visitor = create(:user)
      chain = build_chain(3, game: create(:game), creator: owner)
      battle = CreateBattle.call(user: owner, chain: chain).battle
      sign_in(visitor)

      get battle_path(battle)

      expect(response).to redirect_to(battles_path)
    end

    it 'shows the battle to its owner' do
      user = create(:user)
      chain = build_chain(3, game: create(:game), creator: user)
      battle = CreateBattle.call(user: user, chain: chain).battle
      sign_in(user)

      get battle_path(battle)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Battle')
    end
  end

  describe 'POST /achievements/battles/:id/place' do
    let(:user) { create(:user) }
    let(:chain) { build_chain(3, game: create(:game), creator: user) }
    let(:battle) { CreateBattle.call(user: user, chain: chain).battle }

    before do
      allow_any_instance_of(CreateBattle).to receive(:first_mover).and_return('player')
      sign_in(user)
    end

    it 'places a hand card onto the chosen slot' do
      card = battle.player_cards.find { |c| c.zone == 'hand' }

      post place_battle_path(battle), params: { card_id: card.id, slot: 'right' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['board_html']).to include('battle-board')
      expect(card.reload.zone).to eq('board')
      expect(card.slot).to eq('right')
    end

    it 'returns a JSON error for an invalid placement without changing battle state' do
      post place_battle_path(battle), params: { card_id: -1, slot: 'left' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to be_present
    end

    it 'rejects placing once the battle is already over' do
      battle.update!(status: 'won')
      card = battle.player_cards.find { |c| c.zone == 'hand' }

      post place_battle_path(battle), params: { card_id: card.id, slot: 'left' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "blocks acting on someone else's battle" do
      visitor = create(:user)
      sign_in(visitor)
      card = battle.player_cards.find { |c| c.zone == 'hand' }

      post place_battle_path(battle), params: { card_id: card.id, slot: 'left' }, headers: { 'Accept' => 'application/json' }

      expect(response).to redirect_to(battles_path)
    end
  end

  describe 'POST /achievements/battles/:id/attack' do
    let(:user) { create(:user) }
    let(:chain) { build_chain(3, game: create(:game), creator: user) }
    let(:battle) { CreateBattle.call(user: user, chain: chain).battle }

    before do
      # Deterministic: always player-first, so these specs don't depend on
      # CreateBattle's random coin flip (which can otherwise seed an opening
      # AI move before the spec even starts acting).
      allow_any_instance_of(CreateBattle).to receive(:first_mover).and_return('player')
      sign_in(user)
    end

    # Only a board card can attack -- place one first (bypassing the real
    # PlaceBattleCard flow, since that's tested on its own) and clear
    # acted_this_turn since placing marks a card acted.
    def board_card_for(battle)
      card = battle.player_cards.find { |c| c.zone == 'hand' }
      card.update!(zone: 'board', slot: 'left', acted_this_turn: false)
      card
    end

    it "resolves a single attack instantly and doesn't end the player's turn" do
      card = board_card_for(battle)

      post attack_battle_path(battle), params: { acting_card_id: card.id, target_type: 'player' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['board_html']).to include('battle-board')
      expect(json['move_html']).to include('battle-log__entry')
      expect(battle.reload.current_turn_side).to eq('player')
    end

    it 'includes a death notice in the move log when the attack kills its target' do
      card = board_card_for(battle)
      weak_target = battle.opponent_cards.find { |c| c.zone == 'hand' }
      weak_target.update!(zone: 'board', slot: 'left', hp_current: 1)

      post attack_battle_path(battle), params: { acting_card_id: card.id, target_type: 'card', target_battle_card_id: weak_target.id }, headers: { 'Accept' => 'application/json' }

      expect(response.parsed_body['move_html']).to include('died!')
    end

    it 'returns a JSON error for an invalid attack without changing battle state' do
      post attack_battle_path(battle), params: { acting_card_id: -1, target_type: 'player' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to be_present
      expect(battle.reload.battle_moves.count).to eq(0)
    end

    it "rejects a hand card acting directly -- it must be placed first" do
      card = battle.player_cards.find { |c| c.zone == 'hand' }

      post attack_battle_path(battle), params: { acting_card_id: card.id, target_type: 'player' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an attack once the battle is already over' do
      card = board_card_for(battle)
      battle.update!(status: 'won')

      post attack_battle_path(battle), params: { acting_card_id: card.id, target_type: 'player' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "blocks acting on someone else's battle" do
      card = board_card_for(battle)
      visitor = create(:user)
      sign_in(visitor)

      post attack_battle_path(battle), params: { acting_card_id: card.id, target_type: 'player' }, headers: { 'Accept' => 'application/json' }

      expect(response).to redirect_to(battles_path)
    end
  end

  describe 'POST /achievements/battles/:id/end_turn' do
    let(:user) { create(:user) }
    let(:chain) { build_chain(3, game: create(:game), creator: user) }
    let(:battle) { CreateBattle.call(user: user, chain: chain).battle }

    before do
      allow_any_instance_of(CreateBattle).to receive(:first_mover).and_return('player')
      sign_in(user)
    end

    it "resolves the opponent's whole reply turn, one step per action, and hands back to the player" do
      post end_turn_battle_path(battle), headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      # Mirrored deck, empty board -- the opponent's reply is a single
      # placement (only one card may be placed per side per turn, and it
      # can't also attack the turn it's placed), so exactly one step with
      # no move (nothing attacked).
      expect(json['steps'].size).to eq(1)
      expect(json['steps'].first['board_html']).to include('battle-board')
      expect(json['steps'].first['move_html']).to be_nil
      expect(json['final_html']).to include('battle-board')
      expect(battle.reload.current_turn_side).to eq('player')
    end

    it 'rejects ending the turn once the battle is already over' do
      battle.update!(status: 'won')

      post end_turn_battle_path(battle), headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "blocks ending someone else's battle's turn" do
      visitor = create(:user)
      sign_in(visitor)

      post end_turn_battle_path(battle), headers: { 'Accept' => 'application/json' }

      expect(response).to redirect_to(battles_path)
    end
  end

  describe 'GET /achievements/battles' do
    it "lists the current user's battles" do
      user = create(:user)
      chain = build_chain(3, game: create(:game), creator: user)
      battle = CreateBattle.call(user: user, chain: chain).battle
      sign_in(user)

      get battles_path

      expect(response.body).to include(chain.title)
      expect(response.body).to include(battle_path(battle))
    end
  end
end
