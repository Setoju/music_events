require "rails_helper"

RSpec.describe Review, type: :model do
  subject(:review) { build(:review) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:event) }
  it { is_expected.to define_enum_for(:rating).with_values(could_be_better: 0, good: 1, great: 2, perfect: 3) }
  it { is_expected.to validate_presence_of(:rating) }
  it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:event_id).with_message("has already reviewed this event") }

  describe "validations" do
    it "is invalid if user has no booking for the event" do
      user = create(:user)
      event = create(:event, starts_at: 1.day.ago)
      review = described_class.new(user: user, event: event, rating: :good)

      expect(review).not_to be_valid
      expect(review.errors[:base]).to include("Only users with bookings can review this event")
    end

    it "is invalid when event has not started yet" do
      user = create(:user)
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      review = described_class.new(user: user, event: event, rating: :great)

      expect(review).not_to be_valid
      expect(review.errors[:base]).to include("Review can be created only after the event starts")
    end

    it "is invalid when user reviews the same event twice" do
      user = create(:user)
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)
      create(:review, user: user, event: event, rating: :perfect)
      duplicate_review = described_class.new(user: user, event: event, rating: :great)

      expect(duplicate_review).not_to be_valid
      expect(duplicate_review.errors[:user_id]).to include("has already reviewed this event")
    end
  end
end
