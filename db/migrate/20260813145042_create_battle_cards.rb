class CreateBattleCards < ActiveRecord::Migration[8.1]
  def change
    create_table :battle_cards do |t|
      t.references :battle, null: false, foreign_key: true
      t.string :side, null: false
      t.references :achievement, null: false, foreign_key: true
      t.integer :hp_max, null: false
      t.integer :hp_current, null: false
      t.integer :dmg, null: false
      t.string :zone, null: false, default: "deck"
      t.string :slot
      t.integer :deck_position, null: false

      t.timestamps
    end

    add_index :battle_cards, [:battle_id, :side]
  end
end
