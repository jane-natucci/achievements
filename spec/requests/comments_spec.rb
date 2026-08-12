# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Comments', type: :request do
  def sign_in(user)
    allow(Steam::User).to receive(:summary).and_return('personaname' => user.display_name)
    allow(SyncUserAchievementProgressWorker).to receive(:perform_async)
    post '/achievements/login', params: { profile_url: user.steam_id }
  end

  describe 'POST /achievements/comments' do
    it 'posts a comment on a chain when logged in' do
      user = create(:user)
      chain = create(:chain)
      sign_in(user)

      expect {
        post comments_path, params: { commentable_type: 'Chain', commentable_id: chain.id, comment: { body: 'Nice chain!' } }
      }.to change { chain.comments.count }.by(1)

      expect(response).to redirect_to(chain_path(chain))
      expect(chain.comments.last.user).to eq(user)
    end

    it "awards a one-time bonus for a user's first comment ever, not on later comments" do
      user = create(:user)
      chain_a = create(:chain)
      chain_b = create(:chain)
      sign_in(user)

      expect {
        post comments_path, params: { commentable_type: 'Chain', commentable_id: chain_a.id, comment: { body: 'First!' } }
      }.to change { user.reload.total_xp }.by(XpRules::FIRST_COMMENT_BONUS)
      expect(user.xp_events.where(reason: 'first_comment').count).to eq(1)

      expect {
        post comments_path, params: { commentable_type: 'Chain', commentable_id: chain_b.id, comment: { body: 'Second!' } }
      }.not_to(change { user.reload.total_xp })
      expect(user.xp_events.where(reason: 'first_comment').count).to eq(1)
    end

    it 'posts a comment on an achievement' do
      user = create(:user)
      achievement = create(:achievement)
      sign_in(user)

      expect {
        post comments_path, params: { commentable_type: 'Achievement', commentable_id: achievement.id, comment: { body: 'Tough one.' } }
      }.to change { achievement.comments.count }.by(1)

      expect(response).to redirect_to(achievement_path(achievement))
    end

    it "posts a comment on a user's profile" do
      user = create(:user)
      profile_owner = create(:user)
      sign_in(user)

      expect {
        post comments_path, params: { commentable_type: 'User', commentable_id: profile_owner.id, comment: { body: 'GG!' } }
      }.to change { profile_owner.comments.count }.by(1)

      expect(response).to redirect_to(user_path(profile_owner))
    end

    it 'redirects to login when not signed in' do
      chain = create(:chain)

      expect {
        post comments_path, params: { commentable_type: 'Chain', commentable_id: chain.id, comment: { body: 'Nice chain!' } }
      }.not_to change { Comment.count }

      expect(response).to redirect_to('/achievements/login/')
    end

    it 'rejects a commentable_type outside the allowlist instead of constantizing arbitrary input' do
      user = create(:user)
      sign_in(user)

      expect {
        post comments_path, params: { commentable_type: 'ActiveRecord::Base', commentable_id: 1, comment: { body: 'hi' } }
      }.not_to change { Comment.count }
    end

    it 'rejects a blank comment body' do
      user = create(:user)
      chain = create(:chain)
      sign_in(user)

      expect {
        post comments_path, params: { commentable_type: 'Chain', commentable_id: chain.id, comment: { body: '' } }
      }.not_to change { Comment.count }
    end
  end

  describe 'DELETE /achievements/comments/:id' do
    it "lets a user delete their own comment" do
      user = create(:user)
      comment = create(:comment, user: user)
      sign_in(user)

      expect { delete comment_path(comment) }.to change { Comment.count }.by(-1)
    end

    it "blocks deleting someone else's comment" do
      author = create(:user)
      other_user = create(:user)
      comment = create(:comment, user: author)
      sign_in(other_user)

      expect { delete comment_path(comment) }.not_to change { Comment.count }
      expect(response).to redirect_to(polymorphic_path(comment.commentable))
    end
  end

  describe 'comments render on show pages' do
    it 'shows existing comments and a form on a chain page' do
      user = create(:user)
      chain = create(:chain)
      create(:comment, commentable: chain, body: 'Great starter chain')
      sign_in(user)

      get chain_path(chain)

      expect(response.body).to include('Great starter chain')
      expect(response.body).to include('Post Comment')
    end

    it 'prompts a logged-out visitor to log in instead of showing the form' do
      chain = create(:chain)

      get chain_path(chain)

      expect(response.body).to include('to leave a comment')
      expect(response.body).not_to include('Post Comment')
    end
  end
end
