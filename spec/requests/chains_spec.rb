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
end
