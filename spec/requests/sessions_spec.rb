# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  describe 'GET /login/steam' do
    it 'redirects to the Steam OpenID authorize URL' do
      get '/login/steam'

      expect(response).to redirect_to(a_string_starting_with('https://steamcommunity.com/openid/login'))
    end
  end

  describe 'GET /login/steam/callback' do
    it 'signs the user in and marks the session as steam-verified when Steam confirms the identity' do
      user = create(:user)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam/callback'

      expect(response).to redirect_to('/')
      expect(session[:user_id]).to eq(user.id)
      expect(session[:steam_verified]).to be(true)
    end

    it 'redirects back to login with an alert when Steam verification fails' do
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(nil)

      get '/login/steam/callback'

      expect(response).to redirect_to('/login/')
      follow_redirect!
      expect(response.body).to include('Steam sign-in failed')
    end
  end

  describe 'POST /login' do
    it 'signs the user in without marking the session as steam-verified' do
      user = create(:user)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      post '/login', params: { profile_url: user.steam_id }

      expect(session[:user_id]).to eq(user.id)
      expect(session[:steam_verified]).to be(false)
    end

    it 'clears a stale verified flag from a previous Steam sign-in when switching profiles via paste-URL' do
      verified_user = create(:user)
      other_user = create(:user)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(verified_user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => verified_user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      get '/login/steam/callback'
      expect(session[:steam_verified]).to be(true)

      allow(Steam::User).to receive(:summary).and_return('personaname' => other_user.display_name)
      post '/login', params: { profile_url: other_user.steam_id }

      expect(session[:user_id]).to eq(other_user.id)
      expect(session[:steam_verified]).to be(false)
    end
  end

  describe 'GET /login/steam_id' do
    it 'signs the user in and redirects straight to their profile, unverified' do
      user = create(:user)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id }

      expect(response).to redirect_to("/users/#{user.id}")
      expect(session[:user_id]).to eq(user.id)
      expect(session[:steam_verified]).to be(false)
    end

    it 'redirects to login with an alert when no steam_id is given' do
      get '/login/steam_id'

      expect(response).to redirect_to('/login/')
      follow_redirect!
      expect(response.body).to include('Missing Steam ID')
    end

    it 'redirects to login with an alert when the profile cannot be loaded' do
      allow(Steam::User).to receive(:summary).and_return(nil)

      get '/login/steam_id', params: { steam_id: '76561197960265728' }

      expect(response).to redirect_to('/login/')
      follow_redirect!
      expect(response.body).to include('Could not load that Steam profile')
    end

    it 'redirects to the named achievement, resolved by steam_api_name against EU4, when given' do
      user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      achievement = create(:achievement, game: eu4, steam_api_name: 'ACH_WC_JOIN_HRE')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, achievement: 'ACH_WC_JOIN_HRE' }

      expect(response).to redirect_to("/achievements/#{achievement.id}")
    end

    it 'falls back to the profile page when the named achievement is unknown' do
      user = create(:user)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, achievement: 'NOT_A_REAL_ACHIEVEMENT' }

      expect(response).to redirect_to("/users/#{user.id}")
    end

    it 'auto-creates a chain from achievements[], with the given title and description, and redirects to it' do
      user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      first = create(:achievement, game: eu4, steam_api_name: 'ACH_FIRST')
      second = create(:achievement, game: eu4, steam_api_name: 'ACH_SECOND')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: {
        steam_id: user.steam_id,
        achievements: [ 'ACH_FIRST', 'ACH_SECOND' ],
        title: 'My next steps',
        description: 'Because reasons.'
      }

      chain = Chain.last
      expect(response).to redirect_to("/chains/#{chain.id}")
      expect(chain.title).to eq('My next steps')
      expect(chain.description).to eq('Because reasons.')
      expect(chain.creator).to eq(user)
      expect(chain.nodes_in_order.map(&:ref_id)).to eq([ first.id, second.id ])
    end

    it 'reuses an existing chain instead of creating a duplicate for the same achievements[] and description' do
      user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      create(:achievement, game: eu4, steam_api_name: 'ACH_FIRST')
      create(:achievement, game: eu4, steam_api_name: 'ACH_SECOND')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      params = { steam_id: user.steam_id, achievements: [ 'ACH_FIRST', 'ACH_SECOND' ], description: 'Because reasons.' }

      get '/login/steam_id', params: params
      first_chain = Chain.last

      get '/login/steam_id', params: params

      expect(Chain.count).to eq(1)
      expect(response).to redirect_to("/chains/#{first_chain.id}")
    end

    it 'creates a new chain when the description differs, even with the same achievements' do
      user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      create(:achievement, game: eu4, steam_api_name: 'ACH_FIRST')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'ACH_FIRST' ], description: 'First reason.' }
      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'ACH_FIRST' ], description: 'Second reason.' }

      expect(Chain.count).to eq(2)
    end

    it 'creates a new chain when the achievement sequence differs, even with the same description' do
      user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      create(:achievement, game: eu4, steam_api_name: 'ACH_FIRST')
      create(:achievement, game: eu4, steam_api_name: 'ACH_SECOND')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'ACH_FIRST' ], description: 'Same text.' }
      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'ACH_FIRST', 'ACH_SECOND' ], description: 'Same text.' }

      expect(Chain.count).to eq(2)
    end

    it "does not reuse another user's matching chain" do
      user = create(:user)
      other_user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      create(:achievement, game: eu4, steam_api_name: 'ACH_FIRST')
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      allow(Steam::User).to receive(:summary).and_return('personaname' => other_user.display_name)
      get '/login/steam_id', params: { steam_id: other_user.steam_id, achievements: [ 'ACH_FIRST' ], description: 'Same text.' }

      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'ACH_FIRST' ], description: 'Same text.' }

      expect(Chain.count).to eq(2)
    end

    it 'defaults the chain title when none is given' do
      user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID, name: 'Europa Universalis IV')
      create(:achievement, game: eu4, steam_api_name: 'ACH_FIRST')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'ACH_FIRST' ] }

      expect(Chain.last.title).to eq('Suggested by Europa Universalis IV Strength Score')
    end

    it 'awards chain-creation XP the same way the normal chain-builder does' do
      user = create(:user)
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      create(:achievement, game: eu4, steam_api_name: 'ACH_FIRST')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'ACH_FIRST' ] }

      expect(XpEvent.where(user: user, reason: 'chain_created')).to exist
    end

    it 'falls back to the profile page when none of achievements[] resolve' do
      user = create(:user)
      create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, achievements: [ 'NOT_REAL' ] }

      expect(response).to redirect_to("/users/#{user.id}")
      expect(Chain.count).to eq(0)
    end

    it 'resolves the named achievement against the game named by steam_app_id, not EU4' do
      user = create(:user)
      vic3 = create(:game, steam_app_id: 529_340, name: 'Victoria 3')
      eu4 = create(:game, steam_app_id: Game::EU4_STEAM_APP_ID)
      create(:achievement, game: eu4, steam_api_name: 'ACH_SHARED_NAME')
      vic3_achievement = create(:achievement, game: vic3, steam_api_name: 'ACH_SHARED_NAME')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, steam_app_id: 529_340, achievement: 'ACH_SHARED_NAME' }

      expect(response).to redirect_to("/achievements/#{vic3_achievement.id}")
    end

    it 'auto-creates a chain for a non-EU4 game named by steam_app_id, with a matching default title' do
      user = create(:user)
      vic3 = create(:game, steam_app_id: 529_340, name: 'Victoria 3')
      achievement = create(:achievement, game: vic3, steam_api_name: 'ACH_FIRST')
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam_id', params: { steam_id: user.steam_id, steam_app_id: 529_340, achievements: [ 'ACH_FIRST' ] }

      chain = Chain.last
      expect(response).to redirect_to("/chains/#{chain.id}")
      expect(chain.game).to eq(vic3)
      expect(chain.title).to eq('Suggested by Victoria 3 Strength Score')
      expect(chain.nodes_in_order.map(&:ref_id)).to eq([ achievement.id ])
    end
  end

  describe 'DELETE /logout' do
    it 'clears both the user and the verified flag' do
      user = create(:user)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      get '/login/steam/callback'

      delete '/logout'

      expect(session[:user_id]).to be_nil
      expect(session[:steam_verified]).to be_nil
    end
  end

  describe 'signing in marks the user online right away' do
    it 'via Steam OpenID' do
      user = create(:user, last_seen_at: nil)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      get '/login/steam/callback'

      expect(user.reload.online?).to be(true)
    end

    it 'via paste-URL' do
      user = create(:user, last_seen_at: nil)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)

      post '/login', params: { profile_url: user.steam_id }

      expect(user.reload.online?).to be(true)
    end
  end

  describe 'POST /heartbeat' do
    it "updates the logged-in user's last_seen_at" do
      user = create(:user, last_seen_at: 1.hour.ago)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      post '/login', params: { profile_url: user.steam_id }

      post '/heartbeat'

      expect(response).to have_http_status(:ok)
      expect(user.reload.online?).to be(true)
    end

    it 'no-ops when logged out, without raising' do
      post '/heartbeat'

      expect(response).to have_http_status(:ok)
    end
  end
end
