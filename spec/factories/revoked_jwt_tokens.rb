FactoryBot.define do
  factory :revoked_jwt_token do
    jti { Faker::Alphanumeric.unique.alphanumeric(number: 32) }
    exp { 24.hours.from_now }
  end
end
