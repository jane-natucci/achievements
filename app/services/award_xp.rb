class AwardXp
  def self.call(user:, amount:, reason:, subject: nil, occurred_at: nil)
    return if user.nil? || amount.to_i.zero?

    ActiveRecord::Base.transaction do
      event = XpEvent.create!(user: user, amount: amount, reason: reason, subject: subject)
      event.update_column(:created_at, occurred_at) if occurred_at
      user.increment!(:total_xp, amount)
      event
    end
  end
end
