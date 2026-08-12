class User < ApplicationRecord
  has_many :created_chains, class_name: "Chain", foreign_key: :creator_user_id, dependent: :nullify
  has_many :user_chain_progresses, dependent: :destroy
  has_many :user_node_progresses, dependent: :destroy
  has_many :xp_events, dependent: :destroy
  # Comments received on this user's own profile page.
  has_many :comments, as: :commentable, dependent: :destroy
  # Comments this user has written, anywhere (their own profile, chains,
  # achievements) -- distinct from :comments above, which is the reverse.
  has_many :authored_comments, class_name: "Comment", foreign_key: :user_id, dependent: :destroy
  has_many :favorite_chains, -> { where(user_chain_progresses: { favorite: true }) }, through: :user_chain_progresses, source: :chain
  has_many :user_achievement_favorites, dependent: :destroy
  has_many :favorite_achievements, through: :user_achievement_favorites, source: :achievement
end
