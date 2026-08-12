# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  describe 'GET /achievements/login/steam' do
    it 'redirects to the Steam OpenID authorize URL' do
      get '/achievements/login/steam'

      expect(response).to redirect_to(a_string_starting_with('https://steamcommunity.com/openid/login'))
    end
  end

  describe 'GET /achievements/login/steam/callback' do
    it 'signs the user in and marks the session as steam-verified when Steam confirms the identity' do
      user = create(:user)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/achievements/login/steam/callback'

      expect(response).to redirect_to('/achievements/')
      expect(session[:user_id]).to eq(user.id)
      expect(session[:steam_verified]).to be(true)
    end

    it 'redirects back to login with an alert when Steam verification fails' do
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(nil)

      get '/achievements/login/steam/callback'

      expect(response).to redirect_to('/achievements/login/')
      follow_redirect!
      expect(response.body).to include('Steam sign-in failed')
    end
  end

  describe 'POST /achievements/login' do
    it 'signs the user in without marking the session as steam-verified' do
      user = create(:user)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      post '/achievements/login', params: { profile_url: user.steam_id }

      expect(session[:user_id]).to eq(user.id)
      expect(session[:steam_verified]).to be(false)
    end

    it 'clears a stale verified flag from a previous Steam sign-in when switching profiles via paste-URL' do
      verified_user = create(:user)
      other_user = create(:user)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(verified_user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => verified_user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      get '/achievements/login/steam/callback'
      expect(session[:steam_verified]).to be(true)

      allow(Steam::User).to receive(:summary).and_return('personaname' => other_user.display_name)
      post '/achievements/login', params: { profile_url: other_user.steam_id }

      expect(session[:user_id]).to eq(other_user.id)
      expect(session[:steam_verified]).to be(false)
    end
  end

  describe 'DELETE /achievements/logout' do
    it 'clears both the user and the verified flag' do
      user = create(:user)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      get '/achievements/login/steam/callback'

      delete '/achievements/logout'

      expect(session[:user_id]).to be_nil
      expect(session[:steam_verified]).to be_nil
    end
  end
end
