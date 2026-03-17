class AddUnlockedAtToUserNodeProgresses < ActiveRecord::Migration[8.1]
  def change
    add_column :user_node_progresses, :unlocked_at, :datetime
  end
end
