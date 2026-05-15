FactoryBot.define do
  factory :event_context do
    association :event, strategy: :create
    weather_data { { "list" => [ { "dt" => Time.current.to_i, "weather" => [ { "main" => "Clear" } ] } ] } }
    weather_status { "success" }
    weather_error { nil }
    weather_fetched_at { Time.current }
    expires_at { 24.hours.from_now }
    parking_info { {} }
    parking_status { "not_fetched" }
    parking_fetched_at { nil }

    trait :with_weather do
      weather_data do
        {
          "list" => [
            { "dt" => Time.current.to_i, "weather" => [ { "main" => "Clear" } ] },
            { "dt" => 1.hour.from_now.to_i, "weather" => [ { "main" => "Clouds" } ] }
          ],
          "city" => { "name" => "Test City" }
        }
      end
      weather_status { "success" }
      weather_error { nil }
    end

    trait :weather_failed do
      weather_data { {} }
      weather_status { "failed" }
      weather_error { "HTTP 500: Service unavailable" }
      weather_fetched_at { Time.current }
      expires_at { nil }
    end

    trait :weather_pending do
      weather_data { {} }
      weather_status { "pending" }
      weather_error { nil }
      weather_fetched_at { nil }
      expires_at { nil }
    end
  end
end