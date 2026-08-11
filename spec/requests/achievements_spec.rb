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
  end
end
