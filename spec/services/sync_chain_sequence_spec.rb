# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SyncChainSequence do
  let(:game) { create(:game) }
  let(:chain) { create(:chain, game: game) }
  let(:achievement_a) { create(:achievement, game: game) }
  let(:achievement_b) { create(:achievement, game: game) }
  let(:achievement_c) { create(:achievement, game: game) }

  describe '.call' do
    it 'creates nodes in the given order with notes, linked by sequence edges' do
      described_class.call(chain, [
        { id: achievement_a.id, note: 'first' },
        { id: achievement_b.id, note: 'second' },
        { id: achievement_c.id, note: nil }
      ])

      ordered = chain.reload.nodes_in_order
      expect(ordered.map(&:ref_id)).to eq([achievement_a.id, achievement_b.id, achievement_c.id])
      expect(ordered.map(&:note)).to eq(['first', 'second', nil])
      expect(chain.chain_edges.pluck(:edge_type).uniq).to eq(['sequence'])
    end

    it 'rebuilds the sequence when called again with a different order' do
      described_class.call(chain, [{ id: achievement_a.id, note: nil }, { id: achievement_b.id, note: nil }])
      described_class.call(chain, [{ id: achievement_b.id, note: 'updated' }, { id: achievement_a.id, note: nil }])

      ordered = chain.reload.nodes_in_order
      expect(ordered.map(&:ref_id)).to eq([achievement_b.id, achievement_a.id])
      expect(ordered.first.note).to eq('updated')
    end

    it 'removes nodes that are no longer selected' do
      described_class.call(chain, [{ id: achievement_a.id, note: nil }, { id: achievement_b.id, note: nil }])
      described_class.call(chain, [{ id: achievement_a.id, note: nil }])

      expect(chain.reload.chain_nodes.pluck(:ref_id)).to eq([achievement_a.id])
    end
  end
end
