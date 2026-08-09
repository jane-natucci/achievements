# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Wizard', type: :request do
  let(:game) { create(:game, steam_app_id: 440) }
  let!(:achievements) do
    Array.new(6) { |n| create(:achievement, game: game, steam_api_name: "ach_#{n}") }
  end
  let(:percentages) do
    achievements.each_with_index.map do |achievement, index|
      { 'name' => achievement.steam_api_name, 'percent' => (90 - index * 10).to_s }
    end
  end

  before do
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    allow(SyncOwnedGamesWorker).to receive(:perform_async)
    allow(Steam::UserStats).to receive(:achievement_percentages).with(440).and_return(percentages)
  end

  it 'walks a logged-out visitor from profile URL to their new chain' do
    allow(Steam::User).to receive(:summary).with('76561199079570785').and_return(
      'personaname' => 'Jane', 'avatarfull' => 'https://example.com/avatar.jpg'
    )
    allow(Steam::Player).to receive(:owned_games).with('76561199079570785', anything).and_return(
      'games' => [{ 'appid' => 440, 'playtime_forever' => 120 }]
    )

    get wizard_path
    expect(response.body).to include('Steam profile URL')

    post wizard_path, params: { profile_url: '76561199079570785' }
    expect(response).to redirect_to(wizard_syncing_path)
    follow_redirect!
    expect(response.body).to include('Finding your games')

    get wizard_sync_status_path
    expect(JSON.parse(response.body)).to eq('done' => false)

    User.find_by(steam_id: '76561199079570785').update!(games_synced_at: Time.current)
    get wizard_sync_status_path
    expect(JSON.parse(response.body)).to eq('done' => true)

    get wizard_game_path
    expect(response.body).to include(game.name)
    expect(response.body).to include('first chain for')

    post wizard_game_path, params: { game_id: game.id }
    expect(response).to redirect_to(wizard_achievement_path(step: 1))

    follow_redirect!
    # tier 1 = the 2 most commonly unlocked achievements
    expect(response.body).to include(achievements[0].title)
    expect(response.body).to include(achievements[1].title)

    post wizard_achievement_path(step: 1), params: { achievement_id: achievements[0].id, note: 'easy one to start' }
    expect(response).to redirect_to(wizard_achievement_path(step: 2))
    follow_redirect!

    post wizard_achievement_path(step: 2), params: { achievement_id: achievements[2].id, note: 'getting harder' }
    expect(response).to redirect_to(wizard_achievement_path(step: 3))
    follow_redirect!
    expect(response.body).to include('Create My Chain')

    expect { post wizard_achievement_path(step: 3), params: { achievement_id: achievements[4].id, note: 'the finale' } }
      .to change(Chain, :count).by(1)

    chain = Chain.last
    expect(response).to redirect_to(wizard_summary_path)
    expect(chain.creator.steam_id).to eq('76561199079570785')
    expect(chain.game).to eq(game)

    ordered = chain.nodes_in_order
    expect(ordered.map(&:ref_id)).to eq([achievements[0].id, achievements[2].id, achievements[4].id])
    expect(ordered.map(&:note)).to eq(['easy one to start', 'getting harder', 'the finale'])

    creator = chain.creator
    # wizard chains always get a description, all 3 wizard steps in this test include a note
    chain_creation_xp = XpRules::CHAIN_CREATED + XpRules::CHAIN_DESCRIPTION_BONUS +
                        (3 * XpRules::ACHIEVEMENT_ADDED_TO_CHAIN) + (3 * XpRules::ACHIEVEMENT_NOTE_BONUS)
    expect(creator.reload.total_xp).to eq(XpRules::PROFILE_CREATED + chain_creation_xp)

    follow_redirect!
    expect(response.body).to include('Chain created')
    expect(response.body).to include("Total: +#{chain_creation_xp} xp")
    expect(response.body).to include('See My Chain')

    get chain_path(chain)
    expect(response).to have_http_status(:ok)
  end

  it 'rejects an achievement_id that is not one of the current step candidates' do
    user = create(:user)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    post wizard_path, params: { profile_url: user.steam_id }
    post wizard_game_path, params: { game_id: game.id }

    other_game_achievement = create(:achievement, game: create(:game))
    post wizard_achievement_path(step: 1), params: { achievement_id: other_game_achievement.id, note: 'nope' }

    expect(response).to redirect_to(wizard_achievement_path(step: 1))
    follow_redirect!
    expect(response.body).to include('Pick one to continue')
  end

  it 'skips straight to the game step when already logged in' do
    allow(Steam::User).to receive(:summary).with('76561197993276293').and_return('personaname' => 'Returning Player')
    post wizard_path, params: { profile_url: '76561197993276293' }

    get wizard_path
    expect(response).to redirect_to(wizard_game_path)
  end

  it 'enqueues the owned-games sync and resets games_synced_at on login' do
    user = create(:user, games_synced_at: 1.day.ago)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)

    expect(SyncOwnedGamesWorker).to receive(:perform_async).with(user.id)
    post wizard_path, params: { profile_url: user.steam_id }

    expect(user.reload.games_synced_at).to be_nil
  end
end
