class AwardXp
  # amount: 0 is allowed on purpose -- some reasons (e.g. favoriting) are
  # meant to appear on the timeline without granting XP, since they're
  # trivially repeatable and would otherwise be an easy leaderboard exploit.
  def self.call(user:, amount:, reason:, subject: nil, occurred_at: nil)
    return if user.nil? || amount.nil?

    ActiveRecord::Base.transaction do
      event = XpEvent.create!(user: user, amount: amount, reason: reason, subject: subject)
      event.update_column(:created_at, occurred_at) if occurred_at
      user.increment!(:total_xp, amount)
      event
    end
  end
end
