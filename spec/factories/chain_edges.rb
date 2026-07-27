# frozen_string_literal: true

FactoryBot.define do
  factory :chain_edge do
    chain
    edge_type { 'sequence' }
    from_node { nil }
    to_node { nil }
  end
end
