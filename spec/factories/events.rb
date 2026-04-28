FactoryBot.define do
  factory :event do
    name { Faker::Music::RockBand.name }
    venue { Faker::Company.name }
    city { Faker::Address.city }
    genre { Faker::Music.genre }
    starts_at { Faker::Time.forward(days: 30, period: :evening) }
    ticket_price { Faker::Commerce.price(range: 10.0..150.0) }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
  end
end
