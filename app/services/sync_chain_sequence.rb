class SyncChainSequence
  def self.call(chain, selected_achievements)
    new(chain, selected_achievements).call
  end

  def initialize(chain, selected_achievements)
    @chain = chain
    @selected_achievements = selected_achievements
  end

  def call
    existing_nodes_by_ref_id = chain.chain_nodes.index_by(&:ref_id)

    ordered_nodes = selected_achievements.map do |item|
      node = existing_nodes_by_ref_id.delete(item[:id]) || chain.chain_nodes.build(ref_id: item[:id])
      node.note = item[:note]
      node.save! if node.new_record? || node.changed?
      node
    end

    chain.chain_edges.delete_all
    existing_nodes_by_ref_id.each_value(&:destroy!)

    ordered_nodes.each_cons(2) do |from_node, to_node|
      chain.chain_edges.create!(from_node: from_node.id, to_node: to_node.id, edge_type: "sequence")
    end

    ordered_nodes
  end

  private

  attr_reader :chain, :selected_achievements
end
