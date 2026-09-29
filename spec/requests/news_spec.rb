# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'News', type: :request do
  describe 'GET /news' do
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

  describe 'GET /news/:id' do
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

  describe 'admin authoring' do
    let(:admin_steam_id) { '76561199079570785' }

    # Only a real Steam OpenID callback sets steam_verified -- the
    # paste-a-profile-URL flow (see the plain #sign_in helper below)
    # deliberately doesn't, and admin? requires it. Mirrors
    # sessions_spec.rb's own GET /login/steam/callback test.
    def sign_in_verified(user)
      allow(SteamOpenid).to receive(:verify_steam_id).and_return(user.steam_id)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      get '/login/steam/callback'
    end

    before { ENV['ADMIN_STEAM_ID'] = admin_steam_id }
    after { ENV.delete('ADMIN_STEAM_ID') }

    describe 'GET /news/new' do
      it 'redirects a non-admin visitor, including one who is Steam-verified but not the admin account' do
        sign_in_verified(create(:user, steam_id: '76561199000000001'))

        get new_news_path

        expect(response).to redirect_to(news_index_path)
        follow_redirect!
        expect(response.body).to include('Not authorized')
      end

      it 'redirects a logged-out visitor' do
        get new_news_path

        expect(response).to redirect_to(news_index_path)
      end

      it 'shows the form to the verified admin' do
        sign_in_verified(create(:user, steam_id: admin_steam_id))

        get new_news_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Post news')
      end
    end

    describe 'POST /news' do
      it 'creates a published post with rendered, sanitized markdown when the admin checks publish now' do
        sign_in_verified(create(:user, steam_id: admin_steam_id))

        post news_index_path, params: {
          news_post: { title: 'Big update', body: "**Bold** and <script>alert(1)</script>", publish_now: '1' }
        }

        post_record = NewsPost.find_by!(title: 'Big update')
        expect(response).to redirect_to(news_path(post_record))
        expect(post_record.published_at).to be_present

        get news_path(post_record)
        expect(response.body).to include('<strong>Bold</strong>')
        expect(response.body).not_to include('<script>')
      end

      it 'creates a draft (published_at nil) when publish now is left unchecked' do
        sign_in_verified(create(:user, steam_id: admin_steam_id))

        post news_index_path, params: { news_post: { title: 'Draft', body: 'Body' } }

        expect(NewsPost.find_by!(title: 'Draft').published_at).to be_nil
      end

      it 'is forbidden for a non-admin' do
        sign_in_verified(create(:user, steam_id: '76561199000000002'))

        expect {
          post news_index_path, params: { news_post: { title: 'Nope', body: 'Body' } }
        }.not_to change(NewsPost, :count)
      end
    end

    describe 'draft visibility' do
      it "lets the admin preview their own draft, but 404s it for anyone else" do
        draft = NewsPost.create!(title: 'Unfinished', body: 'Body', published_at: nil)

        sign_in_verified(create(:user, steam_id: admin_steam_id))
        get news_path(draft)
        expect(response).to have_http_status(:ok)

        sign_in_verified(create(:user, steam_id: '76561199000000003'))
        get news_path(draft)
        expect(response).to have_http_status(:not_found)
      end

      it "lists drafts to the admin on the index, but not to anyone else" do
        NewsPost.create!(title: 'Secret draft', body: 'Body', published_at: nil)

        sign_in_verified(create(:user, steam_id: admin_steam_id))
        get news_index_path
        expect(response.body).to include('Secret draft')

        sign_in_verified(create(:user, steam_id: '76561199000000004'))
        get news_index_path
        expect(response.body).not_to include('Secret draft')
      end
    end

    describe 'PATCH /news/:id' do
      it "lets the admin edit their own post, including turning a draft into a published one" do
        draft = NewsPost.create!(title: 'WIP', body: 'Old body', published_at: nil)
        sign_in_verified(create(:user, steam_id: admin_steam_id))

        patch news_path(draft), params: { news_post: { title: 'WIP', body: 'New body', publish_now: '1' } }

        draft.reload
        expect(draft.body).to eq('New body')
        expect(draft.published_at).to be_present
      end

      it 'is forbidden for a non-admin' do
        post_record = NewsPost.create!(title: 'Live', body: 'Body', published_at: 1.day.ago)
        sign_in_verified(create(:user, steam_id: '76561199000000005'))

        patch news_path(post_record), params: { news_post: { title: 'Live', body: 'Hacked' } }

        expect(post_record.reload.body).to eq('Body')
      end
    end
  end

  describe 'unread news indicator' do
    def sign_in(user)
      allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
      allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
      post '/login', params: { profile_url: user.steam_id }
    end

    it 'shows a dot for a logged-out visitor when published news exists' do
      NewsPost.create!(title: 'Hello', body: 'Body', published_at: 1.day.ago)

      get '/'

      expect(response.body).to include('unread-dot')
    end

    it 'shows no dot when there is no published news' do
      NewsPost.create!(title: 'Draft', body: 'Body', published_at: nil)

      get '/'

      expect(response.body).not_to include('unread-dot')
    end

    it "shows a dot for a logged-in user who hasn't read a post published since they joined, and clears it after visiting the news index" do
      user = create(:user, created_at: 2.days.ago)
      NewsPost.create!(title: 'Hello', body: 'Body', published_at: 1.day.ago)
      sign_in(user)

      get '/'
      expect(response.body).to include('unread-dot')

      get news_index_path
      get '/'

      expect(response.body).not_to include('unread-dot')
    end

    it 'shows the dot again once a newer post is published after the user last read' do
      user = create(:user, last_news_read_at: 1.hour.ago)
      NewsPost.create!(title: 'Brand new', body: 'Body', published_at: Time.current)
      sign_in(user)

      get '/'

      expect(response.body).to include('unread-dot')
    end

    it "does not show a dot for a new signup over a backlog of news that predates their registration" do
      # Regression test: last_news_read_at starts nil for every new user,
      # and treating nil as "everything ever published is unread" would
      # mean a signup joining after 100 old news posts already existed
      # sees the dot lit for that entire backlog, none of which was ever
      # actually new to them.
      NewsPost.create!(title: 'Old news', body: 'Body', published_at: 10.days.ago)
      user = create(:user, created_at: Time.current, last_news_read_at: nil)
      sign_in(user)

      get '/'

      expect(response.body).not_to include('unread-dot')
    end
  end
end
