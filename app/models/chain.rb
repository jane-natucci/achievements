class Chain < ApplicationRecord
  include Discard::Model

  belongs_to :game
  belongs_to :creator, class_name: "User", foreign_key: :creator_user_id, optional: true

  has_many :chain_edges, dependent: :destroy
  has_many :chain_nodes, dependent: :destroy
  has_many :user_chain_progresses, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  def nodes
    chain_nodes.loaded? ? chain_nodes : chain_nodes.includes(:achievement)
  end

  def edges
    chain_edges.loaded? ? chain_edges : chain_edges.includes(:achievement)
  end

  def head
    nodes_in_order.first
  end

  def tail
    nodes_in_order.last
  end

  # Walks chain_nodes/chain_edges entirely in memory so this doesn't
  # issue a DB query per node (see achievements#29).
  def nodes_in_order
    all_nodes = nodes.to_a
    return [] if all_nodes.empty?

    all_edges = edges.to_a
    nodes_by_id = all_nodes.index_by(&:id)
    edge_by_from_node = all_edges.index_by(&:from_node)
    to_node_ids = all_edges.map(&:to_node).to_set

    head_node = all_nodes.find { |node| !to_node_ids.include?(node.id) }
    return [] unless head_node

    ordered_nodes = []
    current_node = head_node

    while current_node
      ordered_nodes << current_node
      next_edge = edge_by_from_node[current_node.id]
      current_node = next_edge && nodes_by_id[next_edge.to_node]
    end

    ordered_nodes
  end
end
