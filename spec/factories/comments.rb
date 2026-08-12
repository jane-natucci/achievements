# frozen_string_literal: true

FactoryBot.define do
  factory :comment do
    user
    commentable { association(:chain) }
    sequence(:body) { |n| "Comment #{n}" }
  end
end
