class CreateChains < ActiveRecord::Migration[8.1]
  def change
    create_table :chains do |t|
      t.references :game, null: false, foreign_key: true
      t.string :title
      t.string :slug
      t.text :description
      t.bigint :creator_user_id
      t.string :visibility
      t.integer :featured_score

      t.timestamps
    end

    add_index :chains, :slug, unique: true
    add_index :chains, :creator_user_id
  end
end
