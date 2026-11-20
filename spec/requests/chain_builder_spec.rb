# frozen_string_literal: true

require 'rails_helper'

# The new/edit chain form used to put every achievement of every game into the page. With many games synced that page
# took minutes to build and took the whole site down (2026-11-20). Now it lists only the games, and the builder fetches
# a game's achievements when one is picked.
RSpec.describe 'Chain builder', type: :request do
  def sign_in(user)
    allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    get '/login/steam/callback'
  end

  let!(:ck3) { create(:game, name: 'Crusader Kings III') }
  let!(:eu4) { create(:game, name: 'Europa Universalis IV') }
  let!(:wedding) { create(:achievement, game: ck3, title: 'Until Death Do Us Part', description: 'Marry another character') }
  let!(:emerald) { create(:achievement, game: ck3, title: 'The Emerald Isle', icon_unlocked: 'https://example.com/isle.jpg') }
  let!(:eu4_only) { create(:achievement, game: eu4, title: 'A Fine Kingdom') }

  describe 'GET /chains/new' do
    it 'lists every game but none of their achievements' do
      get new_chain_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Crusader Kings III', 'Europa Universalis IV')
      expect(response.body).not_to include('Until Death Do Us Part', 'A Fine Kingdom')
    end

    it "points the builder at the address it fetches a game's achievements from" do
      get new_chain_path

      expect(response.body).to include('data-chain-builder-achievements-url-value="/games/:game_id/achievements"')
    end
  end

  describe 'GET /chains/:id/edit' do
    it "includes only the chain's own game's achievements, so the steps already chosen can be shown" do
      user = create(:user)
      chain = create(:chain, creator: user, game: ck3)
      sign_in(user)

      get edit_chain_path(chain)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Until Death Do Us Part')
      expect(response.body).not_to include('A Fine Kingdom')
    end
  end

  describe 'GET /games/:game_id/achievements' do
    it "returns that game's achievements as JSON, by title" do
      get game_achievements_path(ck3), as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([
        { 'id' => emerald.id, 'title' => 'The Emerald Isle', 'description' => nil, 'icon_unlocked' => 'https://example.com/isle.jpg' },
        { 'id' => wedding.id, 'title' => 'Until Death Do Us Part', 'description' => 'Marry another character', 'icon_unlocked' => nil }
      ])
    end

    it 'is a 404 for a game that does not exist' do
      get game_achievements_path(game_id: 0), as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  it 'still creates a chain with a note on each step' do
    user = create(:user)
    sign_in(user)
    payload = [{ id: wedding.id, note: 'Christmas Day.' }, { id: emerald.id, note: 'About 90% of the island.' }].to_json

    post chains_path, params: { chain: { title: 'Two years of CK3', game_id: ck3.id, selected_achievement_ids: payload } }

    chain = Chain.last
    expect(response).to redirect_to(chain_path(chain))
    expect(chain.nodes_in_order.map { |node| [node.title, node.note] })
      .to eq([['Until Death Do Us Part', 'Christmas Day.'], ['The Emerald Isle', 'About 90% of the island.']])
  end
end
