FactoryBot.define do
  factory :post do
    association :trip
    user { trip.user }

    sequence(:body) { |n| "テスト投稿#{n}" }
    latitude { 35.681236 }
    longitude { 139.767125 }
    visibility { :inherit_trip }
    visited_at { Time.current }
  end
end
