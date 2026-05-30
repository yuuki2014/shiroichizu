FactoryBot.define do
  factory :user do
    sequence(:nickname) { |n| "テスト#{n}号" }
    sequence(:email) { |n| "test_#{n}@example.com" }
    password { "password" }
    password_confirmation { "password" }
  end
end
