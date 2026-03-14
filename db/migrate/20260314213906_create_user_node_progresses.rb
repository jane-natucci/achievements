class CreateUserNodeProgresses < ActiveRecord::Migration[8.1]
  def change
    create_table :user_node_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :chain_node, null: false, foreign_key: true
      t.string :status
      t.string :source

      t.timestamps
    end

    add_index :user_node_progresses, [:user_id, :chain_node_id], unique: true
  end
end
