# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Users', type: :request do
  describe 'GET /achievements/leaderboard' do
    it 'orders players by total_xp descending' do
      low = create(:user, display_name: 'Low', total_xp: 10)
      high = create(:user, display_name: 'High', total_xp: 500)
      mid = create(:user, display_name: 'Mid', total_xp: 100)

      get leaderboard_path

      expect(response).to have_http_status(:ok)
      body = response.body
      expect(body.index(high.display_name)).to be < body.index(mid.display_name)
      expect(body.index(mid.display_name)).to be < body.index(low.display_name)
    end

    it 'links each row to that player\'s profile' do
      user = create(:user, total_xp: 42)

      get leaderboard_path

      expect(response.body).to include(user_path(user))
    end

    it 'shows achievements-unlocked and chains-completed counts' do
      user = create(:user, total_xp: 42)
      game = create(:game)
      chain = create(:chain, game: game, creator: user)
      head_node = create(:chain_node, chain: chain)
      tail_node = create(:chain_node, chain: chain)
      create(:chain_edge, chain: chain, from_node: head_node.id, to_node: tail_node.id)

      UserNodeProgress.create!(user: user, chain_node: head_node, status: "completed")
      UserNodeProgress.create!(user: user, chain_node: tail_node, status: "completed")
      UserChainProgress.create!(user: user, chain: chain, completed_at: Time.current)

      get leaderboard_path

      expect(response.body).to include(">2<") # achievements unlocked
      expect(response.body).to include(">1<") # chains completed
    end
  end

  describe 'GET /achievements/users/:id' do
    it 'shows the basic summary and computes a tied rank correctly' do
      create(:user, total_xp: 150) # ahead of user
      user = create(:user, display_name: 'Jane', total_xp: 100)
      create(:user, total_xp: 100) # tied with user

      get user_path(user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Jane')
      expect(response.body).to include('#2')
    end

    it "renders the xp event feed with links for each reason" do
      user = create(:user)
      game = create(:game)
      chain = create(:chain, game: game, creator: user, title: 'My Chain')
      achievement = create(:achievement, game: game, icon_unlocked: 'https://example.com/icon.png')
      node = create(:chain_node, chain: chain, achievement: achievement)

      AwardXp.call(user: user, amount: 100, reason: 'profile_created')
      AwardXp.call(user: user, amount: 5, reason: 'achievement_unlocked', subject: node)
      AwardXp.call(user: user, amount: 50, reason: 'chain_created', subject: chain)
      AwardXp.call(user: user, amount: 100, reason: 'chain_completed', subject: chain)

      get user_path(user)

      expect(response.body).to include('Created their profile!')
      expect(response.body).to include('Unlocked')
      expect(response.body).to include(node.achievement.title)
      expect(response.body).to include('Created')
      expect(response.body).to include('Completed')
      expect(response.body).to include(chain_path(chain))
      expect(response.body).to include(achievement_path(node.achievement))

      # achievement-related row shows the achievement's own icon...
      expect(response.body).to include('https://example.com/icon.png')
      # ...while chain-related rows show the chain glyph badge instead
      expect(response.body).to include('xp-feed__icon--chain')
      expect(response.body.scan('xp-feed__icon--chain').size).to eq(2) # chain_created + chain_completed

      # created gets a sparkle status glyph; completed stays plain (just the chain glyph)
      expect(response.body.scan('xp-feed__icon-status-glyph').size).to eq(1)
      expect(response.body).to include('✨')
      expect(response.body).not_to include('✅')
    end

    it "shows the user's own avatar for the profile_created event" do
      user = create(:user, avatar_url: 'https://example.com/my-avatar.jpg')
      AwardXp.call(user: user, amount: 100, reason: 'profile_created')

      get user_path(user)

      expect(response.body).to include('https://example.com/my-avatar.jpg')
    end

    it 'renders gracefully when an xp event subject has been deleted' do
      user = create(:user)
      chain = create(:chain, creator: user)
      node = create(:chain_node, chain: chain)
      AwardXp.call(user: user, amount: 5, reason: 'achievement_note', subject: node)
      node.destroy!

      get user_path(user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('an achievement')
    end
  end
end
