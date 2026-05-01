FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@#{Faker::Internet.domain_name}" }
    # Password meets strength requirements: 12+ chars, uppercase, lowercase, number, special char
    password { "SecurePass123!" }
    password_confirmation { "SecurePass123!" }
    role { :user }

    trait :admin do
      role { :admin }
    end
  end
end
