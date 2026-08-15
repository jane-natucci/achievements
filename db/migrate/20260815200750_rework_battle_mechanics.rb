class ReworkBattleMechanics < ActiveRecord::Migration[8.1]
  def change
    add_column :battle_cards, :acted_this_turn, :boolean, null: false, default: false
    add_column :battles, :player_turn_count, :integer, null: false, default: 0
    add_column :battles, :opponent_turn_count, :integer, null: false, default: 0
    remove_column :battle_moves, :stance_used, :string
    rename_column :battle_moves, :turn_number, :move_number
  end
end
