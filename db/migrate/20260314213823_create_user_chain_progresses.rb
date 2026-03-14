class CreateUserChainProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :user_chain_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chain, null: false, foreign_key: true
      t.datetime :started_at
      t.datetime :completed_at
      t.boolean :favorite
      t.boolean :pinned

      t.timestamps
    end

    add_index :user_chain_progresses, [:user_id, :chain_id], unique: true
  end
end
