# frozen_string_literal: true

FactoryBot.define do
  factory :game do
    sequence(:name) { |n| "Game #{n}" }
  end
end
