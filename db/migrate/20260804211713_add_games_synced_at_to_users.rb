class AddGamesSyncedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :games_synced_at, :datetime
  end
end
