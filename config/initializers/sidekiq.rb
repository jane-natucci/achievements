# Refresh Steam display names/avatars once when the Sidekiq process boots
# (e.g. on deploy), in addition to the daily scheduled sync in sidekiq.yml.
# Sidekiq.configure_server only runs in the actual Sidekiq worker process,
# not on web boot, console, or rake tasks.
Sidekiq.configure_server do |config|
  config.on(:startup) do
    SyncUserProfilesWorker.perform_async
  end
end
