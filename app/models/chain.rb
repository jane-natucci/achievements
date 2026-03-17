class Chain < ApplicationRecord
  belongs_to :game
  belongs_to :creator, class_name: "User", foreign_key: :creator_user_id, optional: true

  has_many :chain_nodes, dependent: :destroy
  has_many :chain_edges, dependent: :destroy

  def nodes
    chain_nodes.includes(:achievement)
  end

  def edges
    chain_edges.includes(:achievement)
  end

  def head
    nodes.where.not(id: edges.select(:to_node)).first
  end

  def tail
    nodes.where.not(id: edges.select(:from_node)).first
  end

  def nodes_in_order
    return [] unless head

    ordered_nodes = []
    current_node = head

    while current_node
      ordered_nodes << current_node
      current_node = edges.find_by(from_node: current_node.id)&.to
    end

    ordered_nodes
  end
end
