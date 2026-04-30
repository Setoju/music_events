FactoryBot.define do
  factory :review do
    user
    event { create(:event, starts_at: 1.day.from_now) }
    rating { 4 }
    comment { Faker::Lorem.sentence(word_count: 8) }

    after(:build) do |review|
      review.user = create(:user) if review.user.blank? || review.user.new_record?
      review.event = create(:event, starts_at: 1.day.from_now) if review.event.blank? || review.event.new_record?

      review.event.update_column(:starts_at, 1.day.from_now) unless review.event.upcoming?
      create(:booking, user: review.user, event: review.event) unless Booking.exists?(user_id: review.user.id, event_id: review.event.id)
      review.event.update_column(:starts_at, 1.day.ago)
    end
  end
end
