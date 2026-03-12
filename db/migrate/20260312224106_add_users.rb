class AddUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :steam_id, null: false
      t.string :display_name
      t.string :avatar_url

      t.timestamps
    end

    add_index :users, :steam_id, unique: true
  end
end
