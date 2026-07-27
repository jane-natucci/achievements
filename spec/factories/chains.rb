# frozen_string_literal: true

FactoryBot.define do
  factory :chain do
    game
    sequence(:title) { |n| "Chain #{n}" }
  end
end
