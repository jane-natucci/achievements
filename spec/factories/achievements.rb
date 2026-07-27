# frozen_string_literal: true

FactoryBot.define do
  factory :achievement do
    game
    sequence(:title) { |n| "Achievement #{n}" }
  end
end
