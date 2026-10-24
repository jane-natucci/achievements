# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Search engines', type: :request do
  describe 'GET /robots.txt' do
    it 'names the sitemap on the canonical host and keeps crawlers out of the wizard and the ops screens' do
      get '/robots.txt'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('text/plain')
      expect(response.body).to include('Sitemap: https://achievements.jane.berlin/sitemap.xml')
      expect(response.body).to include('Disallow: /wizard')
    end
  end

  describe 'GET /sitemap.xml' do
    it 'lists the front page, the kept chains, the achievements inside them and published news -- and nothing else' do
      chain = create(:chain)
      node = create(:chain_node, chain: chain)
      hidden = create(:chain)
      hidden.discard
      lonely = create(:achievement)
      post = NewsPost.create!(title: 'Hello', body: 'Body', published_at: 1.day.ago)
      draft = NewsPost.create!(title: 'Draft', body: 'Body', published_at: nil)
      player = create(:user)

      get '/sitemap.xml'

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to include('xml')
      body = response.body
      expect(body).to include('<loc>https://achievements.jane.berlin/</loc>')
      expect(body).to include("<loc>https://achievements.jane.berlin/chains/#{chain.id}</loc>")
      expect(body).to include("<loc>https://achievements.jane.berlin/achievements/#{node.ref_id}</loc>")
      expect(body).to include("<loc>https://achievements.jane.berlin/news/#{post.id}</loc>")
      expect(body).not_to include("/chains/#{hidden.id}<")
      expect(body).not_to include("/achievements/#{lonely.id}<")
      expect(body).not_to include("/news/#{draft.id}<")
      expect(body).not_to include("/users/#{player.id}")
    end
  end

  describe 'page tags' do
    it 'gives a chain its own title, description, canonical address and preview image' do
      chain = create(:chain, title: 'The Long Road', description: 'Walk it from start to end.')
      create(:chain_node, chain: chain)

      get chain_path(chain)

      expect(response.body).to include("<title>The Long Road — achievement chain for #{chain.game.name}</title>")
      expect(response.body).to include('<meta name="description" content="Walk it from start to end.">')
      expect(response.body).to include(%(<link rel="canonical" href="https://achievements.jane.berlin/chains/#{chain.id}">))
    end

    it 'points a page reached under the old host at the canonical host' do
      host! 'achievementchai.nz'

      get '/help'

      expect(response.body).to include('<link rel="canonical" href="https://achievements.jane.berlin/help">')
    end

    it "marks a player's own page noindex" do
      player = create(:user)

      get user_path(player)

      expect(response.body).to include('<meta name="robots" content="noindex, follow">')
    end

    it 'leaves ordinary pages indexable, with the site card as their preview image' do
      get '/help'

      expect(response.body).to include('<meta name="robots" content="index, follow">')
      expect(response.body).to include('<meta property="og:image" content="https://achievements.jane.berlin/og-image.jpg">')
    end
  end
end
