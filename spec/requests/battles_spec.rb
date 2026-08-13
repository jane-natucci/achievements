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

  describe 'POST /achievements/battles/:id/turn' do
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

    it 'resolves a valid turn and returns board html plus an opponent reply' do
      card = battle.player_cards.find { |c| c.zone == 'hand' }

      post turn_battle_path(battle), params: { acting_card_id: card.id, target_type: 'player', stance: 'attack', slot: 'left' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['mid_html']).to include('battle-board')
      expect(json['mid_move_html']).to include('battle-log__entry')
      # opponent reply resolves within the same request unless the battle already ended
      expect(json['final_html']).to be_present unless json['battle_over']
    end

    it 'returns a JSON error for an invalid turn without changing battle state' do
      post turn_battle_path(battle), params: { acting_card_id: -1, target_type: 'player', stance: 'attack', slot: 'left' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['error']).to be_present
      expect(battle.reload.battle_moves.count).to eq(0)
    end

    it 'rejects a turn once the battle is already over' do
      battle.update!(status: 'won')
      card = battle.player_cards.find { |c| c.zone == 'hand' }

      post turn_battle_path(battle), params: { acting_card_id: card.id, target_type: 'player', stance: 'attack', slot: 'left' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "blocks acting on someone else's battle" do
      visitor = create(:user)
      sign_in(visitor)
      card = battle.player_cards.find { |c| c.zone == 'hand' }

      post turn_battle_path(battle), params: { acting_card_id: card.id, target_type: 'player', stance: 'attack', slot: 'left' }, headers: { 'Accept' => 'application/json' }

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
