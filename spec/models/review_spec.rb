require "rails_helper"

RSpec.describe Review, type: :model do
  subject(:review) { build(:review) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:event) }
  it { is_expected.to validate_presence_of(:rating) }
  it { is_expected.to validate_uniqueness_of(:user_id).scoped_to(:event_id).with_message("has already reviewed this event") }
  it { is_expected.to validate_numericality_of(:rating).only_integer.is_greater_than_or_equal_to(1).is_less_than_or_equal_to(5) }

  describe "validations" do
    it "is invalid if user has no booking for the event" do
      user = create(:user)
      event = create(:event, starts_at: 1.day.ago)
      review = described_class.new(user: user, event: event, rating: 4)

      expect(review).not_to be_valid
      expect(review.errors[:base]).to include("Only users with bookings can review this event")
    end

    it "is invalid when event has not started yet" do
      user = create(:user)
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      review = described_class.new(user: user, event: event, rating: 5)

      expect(review).not_to be_valid
      expect(review.errors[:base]).to include("Review can be created only after the event starts")
    end

    it "is invalid when user reviews the same event twice" do
      user = create(:user)
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)
      create(:review, user: user, event: event, rating: 5)
      duplicate_review = described_class.new(user: user, event: event, rating: 4)

      expect(duplicate_review).not_to be_valid
      expect(duplicate_review.errors[:user_id]).to include("has already reviewed this event")
    end

    it "is invalid when rating is outside the 1-5 range" do
      user = create(:user)
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)

      review = described_class.new(user: user, event: event, rating: 6)

      expect(review).not_to be_valid
      expect(review.errors[:rating]).to include("must be less than or equal to 5")
    end
  end
end
