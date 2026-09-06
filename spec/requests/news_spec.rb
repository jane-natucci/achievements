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
end
