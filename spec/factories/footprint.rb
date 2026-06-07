FactoryBot.define do
  factory :footprint do
    association :trip

    latitude { 35.681236 }
    longitude { 139.767125 }
    recorded_at { Time.current }
  end
end
