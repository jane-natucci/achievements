# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Chains index filters', type: :request do
  def sign_in(user)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    post '/achievements/login', params: { profile_url: user.steam_id }
  end

  describe 'By Owner' do
    it 'lists each chain creator as a filter chip, alphabetically' do
      zed = create(:user, display_name: 'Zed')
      amy = create(:user, display_name: 'Amy')
      create(:chain, creator: zed, title: 'Zed Chain')
      create(:chain, creator: amy, title: 'Amy Chain')

      get chains_path

      doc = Nokogiri::HTML::Document.parse(response.body)
      names = doc.css('.game-filter-list')[1].css('a').map(&:text)
      expect(names).to eq([ 'All Owners', 'Amy', 'Zed' ])
    end

    it 'filters the chain list down to one creator' do
      alice = create(:user, display_name: 'Alice')
      bob = create(:user, display_name: 'Bob')
      create(:chain, creator: alice, title: "Alice's Chain")
      create(:chain, creator: bob, title: "Bob's Chain")

      get chains_path(creator: alice.id)

      expect(response.body).to include("Alice&#39;s Chain")
      expect(response.body).not_to include("Bob&#39;s Chain")
      expect(response.body).to include('Showing chains by')
      expect(response.body).to include('Alice')
    end

    it "labels the signed-in viewer's own chip \"You\" and puts it first" do
      viewer = create(:user, display_name: 'AAAA First Alphabetically')
      other = create(:user, display_name: 'ZZZZ Should Sort Last Anyway')
      create(:chain, creator: viewer)
      create(:chain, creator: other)
      sign_in(viewer)

      get chains_path

      doc = Nokogiri::HTML::Document.parse(response.body)
      names = doc.css('.game-filter-list')[1].css('a').map(&:text)
      expect(names).to eq([ 'All Owners', 'You', 'ZZZZ Should Sort Last Anyway' ])
    end

    it 'says "you" (not their own name) when the viewer filters to their own chains' do
      viewer = create(:user, display_name: 'Viewer')
      create(:chain, creator: viewer)
      sign_in(viewer)

      get chains_path(creator: viewer.id)

      expect(response.body).to include('Showing chains by')
      expect(response.body).to include('<strong>you</strong>')
    end

    it 'only lists users who have actually created a (kept) chain' do
      chainless_user = create(:user, display_name: 'Never Made One')
      chain_owner = create(:user, display_name: 'Made One')
      create(:chain, creator: chain_owner)

      get chains_path

      expect(response.body).to include('Made One')
      expect(response.body).not_to include('Never Made One')
    end

    it 'combines with the game filter rather than replacing it' do
      game_a = create(:game, name: 'Game A')
      game_b = create(:game, name: 'Game B')
      alice = create(:user, display_name: 'Alice')
      create(:chain, creator: alice, game: game_a, title: 'A Chain in Game A')
      create(:chain, creator: alice, game: game_b, title: 'A Chain in Game B')

      get chains_path(creator: alice.id, game: game_a.id)

      expect(response.body).to include('A Chain in Game A')
      expect(response.body).not_to include('A Chain in Game B')
    end
  end
end
