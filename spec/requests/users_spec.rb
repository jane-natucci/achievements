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

    it 'shows an online dot for a recently active player and an offline dot for everyone else' do
      online_user = create(:user, display_name: 'Online Alice', last_seen_at: 30.seconds.ago)
      offline_user = create(:user, display_name: 'Offline Bob', last_seen_at: 1.hour.ago)
      never_seen_user = create(:user, display_name: 'NeverSeen Carl', last_seen_at: nil)

      get leaderboard_path

      doc = Nokogiri::HTML::Document.parse(response.body)
      rows = doc.css('.leaderboard-row')
      online_dot = rows.find { |row| row.text.include?('Online Alice') }.at_css('.avatar-status-dot')
      offline_dot = rows.find { |row| row.text.include?('Offline Bob') }.at_css('.avatar-status-dot')
      never_seen_dot = rows.find { |row| row.text.include?('NeverSeen Carl') }.at_css('.avatar-status-dot')

      expect(online_dot['class']).to include('avatar-status-dot--online')
      expect(offline_dot['class']).not_to include('avatar-status-dot--online')
      expect(never_seen_dot['class']).not_to include('avatar-status-dot--online')
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

    it 'shows how many achievements were in the chain on the chain_created event' do
      user = create(:user)
      chain = create(:chain, creator: user, title: 'Small Chain')
      Array.new(3) { create(:chain_node, chain: chain) }
      AwardXp.call(user: user, amount: 50, reason: 'chain_created', subject: chain)

      get user_path(user)

      expect(response.body).to include('3 achievements')
    end

    it "shows the user's own avatar for the profile_created event" do
      user = create(:user, avatar_url: 'https://example.com/my-avatar.jpg')
      AwardXp.call(user: user, amount: 100, reason: 'profile_created')

      get user_path(user)

      expect(response.body).to include('https://example.com/my-avatar.jpg')
    end

    it 'shows an online status dot when the player is recently active' do
      user = create(:user, last_seen_at: 30.seconds.ago)

      get user_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      dot = doc.at_css('.profile-header__avatar-wrap .avatar-status-dot')
      expect(dot['class']).to include('avatar-status-dot--online')
    end

    it "shows an offline status dot when the player hasn't been seen recently" do
      user = create(:user, last_seen_at: 1.hour.ago)

      get user_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      dot = doc.at_css('.profile-header__avatar-wrap .avatar-status-dot')
      expect(dot['class']).not_to include('avatar-status-dot--online')
    end

    it 'shows "Online now" when the player is currently online' do
      user = create(:user, last_seen_at: 30.seconds.ago)

      get user_path(user)

      expect(response.body).to include('Online now')
    end

    it 'shows how long ago the player was last seen when offline' do
      user = create(:user, last_seen_at: 2.hours.ago)

      get user_path(user)

      expect(response.body).to include('Last seen about 2 hours ago')
    end

    it "shows no presence line when the player has never been seen" do
      user = create(:user, last_seen_at: nil)

      get user_path(user)

      expect(response.body).not_to include('Online now')
      expect(response.body).not_to include('Last seen')
    end

    it 'shows a "Wall of Text" icon linking to that achievement for the first_comment event' do
      user = create(:user)
      game = create(:game, name: 'Victoria 3')
      wall_of_text = create(:achievement, game: game, title: 'Wall of Text')
      AwardXp.call(user: user, amount: XpRules::FIRST_COMMENT_BONUS, reason: 'first_comment')

      get user_path(user)

      expect(response.body).to include(UsersHelper::FIRST_COMMENT_ICON_URL)
      expect(response.body).to include(achievement_path(wall_of_text))
    end

    it "falls back to a plain (unlinked) icon if no Wall of Text achievement exists" do
      user = create(:user)
      AwardXp.call(user: user, amount: XpRules::FIRST_COMMENT_BONUS, reason: 'first_comment')

      get user_path(user)

      expect(response.body).to include(UsersHelper::FIRST_COMMENT_ICON_URL)
      expect(response).to have_http_status(:ok)
    end

    it "links an achievement's icon (but not its row's other text) straight to that achievement" do
      user = create(:user)
      game = create(:game)
      achievement = create(:achievement, game: game, icon_unlocked: 'https://example.com/icon.png')
      node = create(:chain_node, chain: create(:chain, game: game), achievement: achievement)
      AwardXp.call(user: user, amount: 5, reason: 'achievement_unlocked', subject: node)

      get user_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      icon_link = doc.at_css('a.xp-feed__icon-link')
      expect(icon_link['href']).to eq(achievement_path(achievement))
    end

    it "links a chain event's cover icon to the chain's cover achievement" do
      user = create(:user)
      game = create(:game)
      cover_achievement = create(:achievement, game: game, icon_unlocked: 'https://example.com/cover.png')
      chain = create(:chain, game: game, creator: user)
      create(:chain_node, chain: chain, achievement: cover_achievement)
      AwardXp.call(user: user, amount: 100, reason: 'chain_completed', subject: chain)

      get user_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      icon_link = doc.at_css('a.xp-feed__icon--chain')
      expect(icon_link['href']).to eq(achievement_path(cover_achievement))
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

    it 'links "a chain" in an achievement_added event to the chain the achievement was added to' do
      user = create(:user)
      chain = create(:chain, creator: user)
      node = create(:chain_node, chain: chain)
      AwardXp.call(user: user, amount: 5, reason: 'achievement_added', subject: node)

      get user_path(user)

      expect(response.body).to include('to <a')
      expect(response.body).to include(">a chain</a>")
      expect(response.body).to include(chain_path(chain))
    end

    it 'falls back to plain "a chain" text when the achievement_added subject has been deleted' do
      user = create(:user)
      chain = create(:chain, creator: user)
      node = create(:chain_node, chain: chain)
      AwardXp.call(user: user, amount: 5, reason: 'achievement_added', subject: node)
      node.destroy!

      get user_path(user)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('to a chain')
      expect(response.body).not_to include(chain_path(chain))
    end
  end

  def sign_in(user)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    post '/achievements/login', params: { profile_url: user.steam_id }
  end

  describe 'achievement wall' do
    it 'shows unlocked achievements in chronological order, newest first' do
      user = create(:user)
      game = create(:game)
      old_achievement = create(:achievement, game: game, title: 'Old One')
      new_achievement = create(:achievement, game: game, title: 'New One')
      UserAchievementUnlock.create!(user: user, achievement: old_achievement, unlocked_at: 10.days.ago, source: 'steam')
      UserAchievementUnlock.create!(user: user, achievement: new_achievement, unlocked_at: 1.day.ago, source: 'steam')

      get user_path(user)

      expect(response.body).to include('Achievement Wall')
      new_index = response.body.index('New One')
      old_index = response.body.index('Old One')
      expect(new_index).to be < old_index
    end

    it "isn't limited to achievements attached to a chain" do
      user = create(:user)
      achievement = create(:achievement, title: 'Standalone')
      UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: 1.day.ago, source: 'steam')

      get user_path(user)

      expect(response.body).to include('Standalone')
    end

    it 'links each tile straight to the achievement page (a plain click navigates)' do
      user = create(:user)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: 1.day.ago, source: 'steam')

      get user_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      tile = doc.at_css('.achievement-wall__tile')
      expect(tile.name).to eq('a')
      expect(tile['href']).to eq(achievement_path(achievement))
    end

    it 'shows an empty state when nothing has been unlocked yet' do
      user = create(:user)

      get user_path(user)

      expect(response.body).to include('No achievements yet')
    end

    it "caps the wall at #{UsersController::ACHIEVEMENT_WALL_LIMIT} and says how many more there are" do
      user = create(:user)
      (UsersController::ACHIEVEMENT_WALL_LIMIT + 5).times do |i|
        achievement = create(:achievement, title: "Achievement #{i}")
        UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: i.days.ago, source: 'steam')
      end

      get user_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      expect(doc.css('.achievement-wall__tile').size).to eq(UsersController::ACHIEVEMENT_WALL_LIMIT)
      expect(response.body).to include("Showing #{UsersController::ACHIEVEMENT_WALL_LIMIT} most recent of")
    end

    it 'shows a pin badge for pinned achievements to any visitor' do
      owner = create(:user)
      visitor = create(:user)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: owner, achievement: achievement, unlocked_at: 1.day.ago, source: 'steam')
      UserAchievementPin.create!(user: owner, achievement: achievement)
      sign_in(visitor)

      get user_path(owner)

      expect(response.body).to include('achievement-wall__tile--pinned')
    end

    it 'shows pin/unpin controls only when viewing your own wall' do
      owner = create(:user)
      visitor = create(:user)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: owner, achievement: achievement, unlocked_at: 1.day.ago, source: 'steam')

      sign_in(visitor)
      get user_path(owner)
      expect(response.body).not_to include('Pin to wall')

      get user_path(visitor)
      # visitor has no unlocks, so nothing to assert pin controls on, but
      # confirm the wall section itself still renders for the owner's view
      expect(response.body).to include('Achievement Wall')
    end

    it 'shows the pin button on your own wall for an unpinned achievement' do
      user = create(:user)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: 1.day.ago, source: 'steam')
      sign_in(user)

      get user_path(user)

      expect(response.body).to include('Pin to wall')
    end

    it 'shows the most popular chain (by favorites) containing the achievement' do
      user = create(:user)
      game = create(:game)
      achievement = create(:achievement, game: game)
      UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: 1.day.ago, source: 'steam')

      unpopular_chain = create(:chain, game: game, title: 'Unpopular Chain')
      create(:chain_node, chain: unpopular_chain, achievement: achievement)

      popular_chain = create(:chain, game: game, title: 'Popular Chain')
      create(:chain_node, chain: popular_chain, achievement: achievement)
      fan = create(:user)
      UserChainProgress.create!(user: fan, chain: popular_chain, favorite: true)

      get user_path(user)

      expect(response.body).to include('Popular Chain')
      expect(response.body).not_to include('Unpopular Chain')
    end

    it 'shows pinned achievements first, most recently pinned first, ahead of unlock order' do
      user = create(:user)
      old_unlock = create(:achievement, title: 'Old Unlock')
      new_unlock = create(:achievement, title: 'New Unlock')
      pinned_first = create(:achievement, title: 'Pinned First')
      pinned_second = create(:achievement, title: 'Pinned Second')
      UserAchievementUnlock.create!(user: user, achievement: old_unlock, unlocked_at: 10.days.ago, source: 'steam')
      UserAchievementUnlock.create!(user: user, achievement: new_unlock, unlocked_at: 1.day.ago, source: 'steam')
      UserAchievementUnlock.create!(user: user, achievement: pinned_first, unlocked_at: 20.days.ago, source: 'steam')
      UserAchievementUnlock.create!(user: user, achievement: pinned_second, unlocked_at: 30.days.ago, source: 'steam')
      UserAchievementPin.create!(user: user, achievement: pinned_first, created_at: 2.days.ago)
      UserAchievementPin.create!(user: user, achievement: pinned_second, created_at: 1.day.ago)

      get user_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      titles = doc.css('.achievement-wall__tile').map { |tile| tile['aria-label'] }
      expect(titles).to eq(['Pinned Second', 'Pinned First', 'New Unlock', 'Old Unlock'])
    end

    it 'shows a "Show all" link when there are more achievements than the cap, linking to the full wall' do
      user = create(:user)
      (UsersController::ACHIEVEMENT_WALL_LIMIT + 1).times do |i|
        achievement = create(:achievement, title: "Achievement #{i}")
        UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: i.days.ago, source: 'steam')
      end

      get user_path(user)

      expect(response.body).to include('Show all')
      expect(response.body).to include(user_wall_path(user))
    end

    it "doesn't show a \"Show all\" link when everything already fits" do
      user = create(:user)
      achievement = create(:achievement)
      UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: 1.day.ago, source: 'steam')

      get user_path(user)

      expect(response.body).not_to include('Show all')
    end
  end

  describe 'GET /achievements/users/:id/wall' do
    it 'shows every unlocked achievement, uncapped' do
      user = create(:user)
      (UsersController::ACHIEVEMENT_WALL_LIMIT + 5).times do |i|
        achievement = create(:achievement, title: "Achievement #{i}")
        UserAchievementUnlock.create!(user: user, achievement: achievement, unlocked_at: i.days.ago, source: 'steam')
      end

      get user_wall_path(user)

      expect(response).to have_http_status(:ok)
      doc = Nokogiri::HTML::Document.parse(response.body)
      expect(doc.css('.achievement-wall__tile').size).to eq(UsersController::ACHIEVEMENT_WALL_LIMIT + 5)
    end

    it 'still orders pinned achievements first' do
      user = create(:user)
      old_unlock = create(:achievement, title: 'Old Unlock')
      pinned = create(:achievement, title: 'Pinned')
      UserAchievementUnlock.create!(user: user, achievement: old_unlock, unlocked_at: 10.days.ago, source: 'steam')
      UserAchievementUnlock.create!(user: user, achievement: pinned, unlocked_at: 20.days.ago, source: 'steam')
      UserAchievementPin.create!(user: user, achievement: pinned)

      get user_wall_path(user)

      doc = Nokogiri::HTML::Document.parse(response.body)
      titles = doc.css('.achievement-wall__tile').map { |tile| tile['aria-label'] }
      expect(titles).to eq(['Pinned', 'Old Unlock'])
    end
  end
end
