FactoryBot.define do
  factory :artist do
    name { Faker::Music.band }
    genre { Faker::Music.genre }
    bio { Faker::Lorem.paragraph(sentence_count: 3) }
    country { Faker::Address.country }
    website { "https://#{Faker::Internet.domain_name}" }
  end
end
