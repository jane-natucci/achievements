class ChainNode < ApplicationRecord
  belongs_to :chain

  belongs_to :achievement, foreign_key: :ref_id
  has_many :user_node_progresses, dependent: :destroy

  before_save :sync_with_achievement

  delegate :icon_locked, to: :achievement, allow_nil: true
  delegate :icon_unlocked, to: :achievement, allow_nil: true

  def title
    achievement&.title || self[:title] || "Unknown Achievement #{id}"
  end

  def description
    achievement&.description || self[:description] || "No description available"
  end

  def display_description
    note.presence || description
  end

  def sync_with_achievement
    return unless achievement

    self.title = achievement.title
    self.description = achievement.description
  end
end
