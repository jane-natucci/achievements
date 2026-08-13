class CreateBattles < ActiveRecord::Migration[8.1]
  def change
    create_table :battles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "active"
      t.integer :player_hp, null: false, default: 30
      t.integer :opponent_hp, null: false, default: 30
      t.string :current_turn_side, null: false
      t.references :deck_chain, null: false, foreign_key: { to_table: :chains }

      t.timestamps
    end
  end
end
