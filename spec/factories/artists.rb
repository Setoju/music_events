FactoryBot.define do
  factory :artist do
    sequence(:name) { |n| "Artist #{n}" }
    genre { "Rock" }
    bio { "Experienced live performer and songwriter." }
    country { "Ukraine" }
    website { "https://example.com" }
  end
end
