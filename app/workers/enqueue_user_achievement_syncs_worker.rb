class EnqueueUserAchievementSyncsWorker
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform
    User.find_each do |user|
      SyncUserAchievementProgressWorker.perform_async(user.id)
    end
  end
end
