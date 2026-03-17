class SyncUserAchievementProgressWorker
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SyncUserAchievementProgress.call(user)
  end
end
