FactoryBot.define do
  factory :trip do
    association :user

    sequence(:title) { |n| "テスト地図#{n}" }
    status { :private }
  end
end
