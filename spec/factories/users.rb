# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:steam_id) { |n| (76561197960265728 + n).to_s }
    sequence(:display_name) { |n| "Player #{n}" }
  end
end
