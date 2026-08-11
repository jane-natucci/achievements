class SyncUserProfiles
  # Steam's GetPlayerSummaries endpoint accepts up to 100 steamids per call.
  BATCH_SIZE = 100

  def self.call
    new.call
  end

  def call
    User.in_batches(of: BATCH_SIZE) do |relation|
      sync_batch(relation.to_a)
    end
  end

  private

  def sync_batch(users)
    users_by_steam_id = users.index_by(&:steam_id)
    summaries = Steam::User.summaries(users_by_steam_id.keys)

    summaries.each do |summary|
      user = users_by_steam_id[summary["steamid"]]
      next unless user

      user.display_name = summary["personaname"]
      user.avatar_url = summary["avatarfull"].presence || summary["avatarmedium"].presence || summary["avatar"]
      user.save! if user.changed?
    end
  end
end
