# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'News', type: :request do
  describe 'GET /achievements/news' do
    it 'lists published posts, newest first' do
      older = NewsPost.create!(title: 'Older post', body: 'Body', published_at: 2.days.ago)
      newer = NewsPost.create!(title: 'Newer post', body: 'Body', published_at: 1.day.ago)

      get news_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body.index(newer.title)).to be < response.body.index(older.title)
    end

    it 'hides unpublished (nil published_at) and future-dated posts' do
      draft = NewsPost.create!(title: 'Draft post', body: 'Body', published_at: nil)
      scheduled = NewsPost.create!(title: 'Scheduled post', body: 'Body', published_at: 1.day.from_now)

      get news_index_path

      expect(response.body).not_to include(draft.title)
      expect(response.body).not_to include(scheduled.title)
    end

    it 'shows an empty state when there are no posts' do
      get news_index_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No news yet')
    end
  end

  describe 'GET /achievements/news/:id' do
    it 'shows a published post' do
      post = NewsPost.create!(title: 'Hello world', body: 'Some announcement.', published_at: 1.day.ago)

      get news_path(post)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Hello world')
      expect(response.body).to include('Some announcement.')
    end

    it "404s for an unpublished post" do
      draft = NewsPost.create!(title: 'Draft post', body: 'Body', published_at: nil)

      get news_path(draft)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'unread news indicator' do
    def sign_in(user)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      post '/achievements/login', params: { profile_url: user.steam_id }
    end

    it 'shows a dot for a logged-out visitor when published news exists' do
      NewsPost.create!(title: 'Hello', body: 'Body', published_at: 1.day.ago)

      get '/achievements/'

      expect(response.body).to include('unread-dot')
    end

    it 'shows no dot when there is no published news' do
      NewsPost.create!(title: 'Draft', body: 'Body', published_at: nil)

      get '/achievements/'

      expect(response.body).not_to include('unread-dot')
    end

    it "shows a dot for a logged-in user who hasn't read the latest post, and clears it after visiting the news index" do
      user = create(:user)
      NewsPost.create!(title: 'Hello', body: 'Body', published_at: 1.day.ago)
      sign_in(user)

      get '/achievements/'
      expect(response.body).to include('unread-dot')

      get news_index_path
      get '/achievements/'

      expect(response.body).not_to include('unread-dot')
    end

    it 'shows the dot again once a newer post is published after the user last read' do
      user = create(:user, last_news_read_at: 1.hour.ago)
      NewsPost.create!(title: 'Brand new', body: 'Body', published_at: Time.current)
      sign_in(user)

      get '/achievements/'

      expect(response.body).to include('unread-dot')
    end
  end
end
