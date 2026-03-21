class AddDiscardedAtToChains < ActiveRecord::Migration[8.1]
  def change
    add_column :chains, :discarded_at, :datetime
    add_index :chains, :discarded_at
  end
end
