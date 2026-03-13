class CreateAchievements < ActiveRecord::Migration[8.1]
  def change
    create_table :achievements do |t|
      t.references :game, null: false, foreign_key: true
      t.string :steam_api_name
      t.string :title
      t.text :description
      t.string :icon_locked
      t.string :icon_unlocked
      t.boolean :hidden

      t.timestamps
    end

    add_index :achievements, [:game_id, :steam_api_name], unique: true
  end
end
