class ChainNode < ApplicationRecord
  belongs_to :chain

  belongs_to :achievement, foreign_key: :ref_id

  before_save :sync_with_achievement

  def title
    achievement&.title || title || "Unknown Achievement #{id}"
  end

  def description
    achievement&.description || description || "No description available"
  end

  def sync_with_achievement
    return unless achievement

    self.title = achievement.title
    self.description = achievement.description
  end
end
