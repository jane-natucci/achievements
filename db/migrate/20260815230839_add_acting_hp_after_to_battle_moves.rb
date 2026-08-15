class AddActingHpAfterToBattleMoves < ActiveRecord::Migration[8.1]
  def change
    add_column :battle_moves, :acting_hp_after, :integer
  end
end
