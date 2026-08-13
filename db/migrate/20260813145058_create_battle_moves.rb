class CreateBattleMoves < ActiveRecord::Migration[8.1]
  def change
    create_table :battle_moves do |t|
      t.references :battle, null: false, foreign_key: true
      t.integer :turn_number, null: false
      t.string :acting_side, null: false
      t.references :acting_battle_card, null: false, foreign_key: { to_table: :battle_cards }
      t.string :target_type, null: false
      t.references :target_battle_card, foreign_key: { to_table: :battle_cards }
      t.string :stance_used, null: false
      t.integer :damage_dealt, null: false
      t.integer :target_hp_after, null: false

      t.timestamps
    end
  end
end
