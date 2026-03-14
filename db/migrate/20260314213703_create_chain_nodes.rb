class CreateChainNodes < ActiveRecord::Migration[8.1]
  def change
    create_table :chain_nodes do |t|
      t.references :chain, null: false, foreign_key: true
      t.string :node_type
      t.bigint :ref_id
      t.string :title
      t.text :description
      t.integer :position_x
      t.integer :position_y

      t.timestamps
    end
  end
end
