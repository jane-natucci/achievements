class SyncOwnedGamesWorker
  include Sidekiq::Job

  sidekiq_options queue: :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    SyncOwnedGames.call(user)
  ensure
    user&.update!(games_synced_at: Time.current)
  end
end
