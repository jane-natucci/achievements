# frozen_string_literal: true

FactoryBot.define do
  factory :chain_node do
    chain
    achievement { create(:achievement, game: chain.game) }
  end
end
