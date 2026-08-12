# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Achievements home', type: :request do
  describe 'GET /achievements' do
    it 'shows a global news feed of recent xp events across all players' do
      alice = create(:user, display_name: 'Alice')
      bob = create(:user, display_name: 'Bob')
      AwardXp.call(user: alice, amount: 100, reason: 'profile_created')
      AwardXp.call(user: bob, amount: 100, reason: 'profile_created')

      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("What's Happening")
      expect(response.body).to include('Alice')
      expect(response.body).to include('Bob')
      expect(response.body).to include(user_path(alice))
      expect(response.body).to include(user_path(bob))
    end

    it 'shows an empty state when nobody has earned xp yet' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nothing yet')
    end

    it 'renders a collapsible mobile nav toggle wired to the nav via Stimulus' do
      get root_path

      expect(response.body).to include('data-controller="topbar-menu"')
      expect(response.body).to include('data-topbar-menu-target="toggle"')
      expect(response.body).to include('data-topbar-menu-target="nav"')
      expect(response.body).to include('aria-controls="topbar-nav"')
      expect(response.body).to include('id="topbar-nav"')
    end
  end

  def sign_in(user)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    post '/achievements/login', params: { profile_url: user.steam_id }
  end

  describe 'GET /achievements/achievements/:id combined history' do
    it 'interleaves unlocks and favorites by time, most recent first' do
      achievement = create(:achievement)
      chain = create(:chain)
      node = create(:chain_node, chain: chain, achievement: achievement)
      alice = create(:user, display_name: 'Alice')
      bob = create(:user, display_name: 'Bob')
      AwardXp.call(user: alice, amount: 5, reason: 'achievement_unlocked', subject: node, occurred_at: 2.days.ago)
      AwardXp.call(user: bob, amount: 0, reason: 'achievement_favorited', subject: achievement, occurred_at: 1.day.ago)

      get achievement_path(achievement)

      expect(response.body).to include('History')
      expect(response.body).to include('Alice')
      expect(response.body).to include('unlocked this')
      expect(response.body).to include('Bob')
      expect(response.body).to include('favorited this')
      bob_index = response.body.index('Bob')
      alice_index = response.body.index('Alice')
      expect(bob_index).to be < alice_index
    end

    it 'shows an empty state when there is no history yet' do
      achievement = create(:achievement)

      get achievement_path(achievement)

      expect(response.body).to include('No activity yet')
    end

    it "doesn't include unlocks belonging to a different achievement" do
      achievement = create(:achievement)
      other_achievement = create(:achievement, game: achievement.game)
      chain = create(:chain)
      node = create(:chain_node, chain: chain, achievement: other_achievement)
      alice = create(:user, display_name: 'Alice')
      AwardXp.call(user: alice, amount: 5, reason: 'achievement_unlocked', subject: node)

      get achievement_path(achievement)

      expect(response.body).to include('No activity yet')
    end

    it 'includes one entry per unlock even if the achievement appears in multiple chains' do
      achievement = create(:achievement)
      chain_a = create(:chain)
      chain_b = create(:chain)
      node_a = create(:chain_node, chain: chain_a, achievement: achievement)
      node_b = create(:chain_node, chain: chain_b, achievement: achievement)
      alice = create(:user, display_name: 'Alice')
      AwardXp.call(user: alice, amount: 5, reason: 'achievement_unlocked', subject: node_a)
      AwardXp.call(user: alice, amount: 5, reason: 'achievement_unlocked', subject: node_b)

      get achievement_path(achievement)

      expect(response.body).to include('2 events')
    end
  end

  describe 'favoriting an achievement' do
    it 'shows a favorite button for a logged-in user' do
      achievement = create(:achievement)
      user = create(:user)
      sign_in(user)

      get achievement_path(achievement)

      expect(response.body).to include('Add to favorites')
    end

    it "doesn't show a favorite button for a logged-out visitor" do
      achievement = create(:achievement)

      get achievement_path(achievement)

      expect(response.body).not_to include('Add to favorites')
    end

    it 'adds the achievement to favorites' do
      achievement = create(:achievement)
      user = create(:user)
      sign_in(user)

      expect {
        post favorite_achievement_path(achievement)
      }.to change { user.favorite_achievements.count }.by(1)

      expect(user.favorite_achievements).to include(achievement)
    end

    it 'removes the achievement from favorites' do
      achievement = create(:achievement)
      user = create(:user)
      sign_in(user)
      UserAchievementFavorite.create!(user: user, achievement: achievement)

      expect {
        delete favorite_achievement_path(achievement)
      }.to change { user.favorite_achievements.count }.by(-1)
    end

    it 'redirects a logged-out visitor to log in instead of favoriting' do
      achievement = create(:achievement)

      expect {
        post favorite_achievement_path(achievement)
      }.not_to change { UserAchievementFavorite.count }

      expect(response).to redirect_to('/achievements/login/')
    end

    it 'puts a no-xp "favorited" entry on the timeline, and removes it on unfavorite' do
      achievement = create(:achievement, title: 'Grind It Out')
      user = create(:user, display_name: 'Alice')
      sign_in(user)

      expect {
        post favorite_achievement_path(achievement)
      }.to change { user.reload.total_xp }.by(0)

      get root_path
      expect(response.body).to include('Favorited')
      expect(response.body).to include('Grind It Out')
      expect(response.body).not_to include('+0 XP')

      delete favorite_achievement_path(achievement)

      get root_path
      expect(response.body).not_to include('Favorited')
    end

    it "doesn't spam the timeline with duplicate entries when the favorite button is hit twice" do
      achievement = create(:achievement)
      user = create(:user)
      sign_in(user)

      post favorite_achievement_path(achievement)
      post favorite_achievement_path(achievement)

      expect(XpEvent.where(user: user, reason: 'achievement_favorited').count).to eq(1)
    end

    it 'shows a visible favorite count and includes the favoriter in the history feed' do
      achievement = create(:achievement)
      alice = create(:user, display_name: 'Alice')
      sign_in(alice)
      post favorite_achievement_path(achievement)

      get achievement_path(achievement)

      expect(response.body).to include('Favorites')
      expect(response.body).to include('Alice')
      expect(response.body).to include('favorited this')
    end
  end
end
