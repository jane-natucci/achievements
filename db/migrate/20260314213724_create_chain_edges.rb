class CreateChainEdges < ActiveRecord::Migration[8.1]
  def change
    create_table :chain_edges do |t|
      t.references :chain, null: false, foreign_key: true
      t.bigint :from_node
      t.bigint :to_node
      t.string :edge_type

      t.timestamps
    end

    add_foreign_key :chain_edges, :chain_nodes, column: :from_node
    add_foreign_key :chain_edges, :chain_nodes, column: :to_node

    add_index :chain_edges, :from_node
    add_index :chain_edges, :to_node
  end
end
