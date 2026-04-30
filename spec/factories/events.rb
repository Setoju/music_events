FactoryBot.define do
  factory :event do
    name { Faker::Music::RockBand.name }
    venue { Faker::Company.name }
    city { Faker::Address.city }
    genre { Faker::Music.genre }
    starts_at { Faker::Time.forward(days: 30, period: :evening) }
    ticket_price { Faker::Commerce.price(range: 10.0..150.0) }
    tickets_capacity { Faker::Number.between(from: 20, to: 200) }
    description { Faker::Lorem.paragraph(sentence_count: 3) }

    # Sample venue coordinates (mix of major US cities)
    latitude { [ 40.7128, 34.0522, 41.8781, 39.7392, 47.6062 ].sample + rand(-0.5..0.5) }
    longitude { [ -74.0060, -118.2437, -87.6298, -104.9903, -122.3321 ].sample + rand(-0.5..0.5) }
  end
end
