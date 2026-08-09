class AddTotalXpToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :total_xp, :integer, null: false, default: 0
  end
end
