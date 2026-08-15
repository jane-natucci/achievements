class AddTurnStartedAtToBattles < ActiveRecord::Migration[8.1]
  def change
    add_column :battles, :turn_started_at, :datetime
  end
end
