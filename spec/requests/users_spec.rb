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
      node = create(:chain_node, chain: chain)

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
