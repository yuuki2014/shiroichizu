FactoryBot.define do
  factory :trip do
    association :user

    sequence(:title) { |n| "テスト地図#{n}" }
    status { :private }
    activity_time { 0 }
    total_distance { 0 }
    started_at { Time.current }
  end
end
