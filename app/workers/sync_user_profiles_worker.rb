class SyncUserProfilesWorker
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform
    SyncUserProfiles.call
  end
end
