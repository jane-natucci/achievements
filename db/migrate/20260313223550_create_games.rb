class CreateGames < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.integer :steam_app_id
      t.string :name
      t.string :icon

      t.timestamps
    end
  end
end
