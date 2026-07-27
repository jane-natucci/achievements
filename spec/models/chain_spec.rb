# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chain, type: :model do
  describe '#nodes_in_order' do
    subject(:nodes_in_order) { chain.nodes_in_order }

    let(:game) { create(:game) }
    let(:chain) { create(:chain, game: game) }

    context 'when the chain has nodes connected in sequence' do
      let!(:node_a) { create(:chain_node, chain: chain) }
      let!(:node_b) { create(:chain_node, chain: chain) }
      let!(:node_c) { create(:chain_node, chain: chain) }

      before do
        # edges created out of order on purpose, so the result can't be relying on insertion order
        create(:chain_edge, chain: chain, from_node: node_b.id, to_node: node_c.id)
        create(:chain_edge, chain: chain, from_node: node_a.id, to_node: node_b.id)
      end

      it 'walks the chain from head to tail' do
        expect(nodes_in_order.map(&:id)).to eq([node_a.id, node_b.id, node_c.id])
      end
    end

    context 'when the chain has no nodes' do
      it 'returns an empty array' do
        expect(nodes_in_order).to eq([])
      end
    end

    context 'when nodes and edges are preloaded' do
      let!(:nodes) { create_list(:chain_node, 12, chain: chain) }

      before do
        nodes.each_cons(2) { |from, to| create(:chain_edge, chain: chain, from_node: from.id, to_node: to.id) }
      end

      it 'does not issue a query per node (regression test for #29)' do
        preloaded_chain = Chain.includes(chain_nodes: :achievement, chain_edges: :achievement).find(chain.id)

        expect_no_sql_called { preloaded_chain.nodes_in_order }
      end
    end

    context 'when nodes and edges are not preloaded' do
      it 'issues the same number of queries regardless of chain length (regression test for #29)' do
        small_chain = create(:chain, game: game)
        small_nodes = create_list(:chain_node, 3, chain: small_chain)
        small_nodes.each_cons(2) { |from, to| create(:chain_edge, chain: small_chain, from_node: from.id, to_node: to.id) }

        large_chain = create(:chain, game: game)
        large_nodes = create_list(:chain_node, 30, chain: large_chain)
        large_nodes.each_cons(2) { |from, to| create(:chain_edge, chain: large_chain, from_node: from.id, to_node: to.id) }

        small_query_count = count_sql_queries { Chain.find(small_chain.id).nodes_in_order }
        large_query_count = count_sql_queries { Chain.find(large_chain.id).nodes_in_order }

        expect(large_query_count).to eq(small_query_count)
      end
    end
  end
end
