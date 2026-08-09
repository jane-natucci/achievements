class CreateXpEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :xp_events do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :amount, null: false
      t.string :reason, null: false
      t.references :subject, polymorphic: true, null: true

      t.timestamps
    end

    add_index :xp_events, [:user_id, :created_at]
  end
end
