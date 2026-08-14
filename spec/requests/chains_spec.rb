# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chains deletion', type: :request do
  def sign_in_via_steam(user)
    allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    get '/achievements/login/steam/callback'
  end

  def sign_in_via_paste_url(user)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    post '/achievements/login', params: { profile_url: user.steam_id }
  end

  describe 'GET /achievements/chains/:id delete button' do
    it 'shows an active delete button for a steam-verified creator' do
      user = create(:user)
      chain = create(:chain, creator: user)
      sign_in_via_steam(user)

      get chain_path(chain)

      expect(response.body).to include('data-turbo-confirm')
      expect(response.body).to include('Delete this chain')
      expect(response.body).not_to include('sidebar-icon-button--muted')
    end

    it 'shows a muted sign-in link for an unverified creator' do
      user = create(:user)
      chain = create(:chain, creator: user)
      sign_in_via_paste_url(user)

      get chain_path(chain)

      expect(response.body).to include('sidebar-icon-button--muted')
      expect(response.body).to include('Sign in with Steam to remove chains')
      expect(response.body).to include('/achievements/login/steam')
    end
  end

  describe 'DELETE /achievements/chains/:id' do
    it 'discards the chain when the creator is signed in via Steam' do
      user = create(:user)
      chain = create(:chain, creator: user)
      sign_in_via_steam(user)

      expect { delete chain_path(chain) }.to change { chain.reload.discarded? }.from(false).to(true)
      expect(response).to redirect_to(chains_path)
    end

    it "removes the chain's xp events (and the xp they earned) so the profile feed doesn't link to a 404" do
      user = create(:user)
      chain = create(:chain, creator: user, description: 'A great chain')
      node = create(:chain_node, chain: chain)
      AwardXp.call(user: user, amount: 50, reason: 'chain_created', subject: chain)
      AwardXp.call(user: user, amount: 25, reason: 'chain_description', subject: chain)
      AwardXp.call(user: user, amount: 5, reason: 'achievement_added', subject: node)
      sign_in_via_steam(user)
      xp_before = user.reload.total_xp

      delete chain_path(chain)

      expect(user.reload.total_xp).to eq(xp_before - 80)
      expect(XpEvent.where(subject: chain).count).to eq(0)
      expect(XpEvent.where(subject: node).count).to eq(0)

      get user_path(user)
      expect(response.body).not_to include('Created')
      expect(response.body).not_to include('Added')
    end

    it 'blocks deletion and explains why when the creator only used the paste-URL login' do
      user = create(:user)
      chain = create(:chain, creator: user)
      sign_in_via_paste_url(user)

      delete chain_path(chain)

      expect(chain.reload.discarded?).to be(false)
      expect(response).to redirect_to(chain_path(chain))
      follow_redirect!
      expect(response.body).to include('Sign in with Steam to remove chains')
    end

    it "still blocks deletion for a steam-verified user who isn't the creator" do
      creator = create(:user)
      chain = create(:chain, creator: creator)
      other_user = create(:user)
      sign_in_via_steam(other_user)

      delete chain_path(chain)

      expect(chain.reload.discarded?).to be(false)
      follow_redirect! if response.redirect?
    end
  end

  describe 'favoriting a chain' do
    it 'puts a no-xp "favorited" entry on the timeline, and removes it on unfavorite' do
      chain = create(:chain, title: 'My Big Run')
      user = create(:user)
      sign_in_via_paste_url(user)

      expect {
        post favorite_chain_path(chain)
      }.to change { user.reload.total_xp }.by(0)

      get root_path
      expect(response.body).to include('Favorited')
      expect(response.body).to include('My Big Run')

      delete favorite_chain_path(chain)

      get root_path
      expect(response.body).not_to include('Favorited')
    end

    it 'shows a visible favorite count in the sidebar' do
      chain = create(:chain)
      user = create(:user)
      sign_in_via_paste_url(user)
      post favorite_chain_path(chain)

      get chain_path(chain)

      expect(response.body).to include('Favorites')
      expect(response.body).to include('>1<')
    end
  end
end
