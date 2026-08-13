class UserAchievementPin < ApplicationRecord
  MAX_PINS_PER_USER = 6

  belongs_to :user
  belongs_to :achievement

  validate :under_pin_limit, on: :create

  private

  def under_pin_limit
    return unless user

    if user.user_achievement_pins.count >= MAX_PINS_PER_USER
      errors.add(:base, "You can only pin up to #{MAX_PINS_PER_USER} achievements. Unpin one first.")
    end
  end
end
