class AwardXp
  def self.call(user:, amount:, reason:, subject: nil)
    return if user.nil? || amount.to_i.zero?

    ActiveRecord::Base.transaction do
      event = XpEvent.create!(user: user, amount: amount, reason: reason, subject: subject)
      user.increment!(:total_xp, amount)
      event
    end
  end
end
