class SyncGlobalAchievementRarityWorker
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform
    SyncGlobalAchievementRarity.call
  end
end
