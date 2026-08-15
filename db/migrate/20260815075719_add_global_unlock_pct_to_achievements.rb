class AddGlobalUnlockPctToAchievements < ActiveRecord::Migration[8.1]
  def change
    add_column :achievements, :global_unlock_pct, :float
  end
end
