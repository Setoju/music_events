require "rails_helper"

RSpec.describe Booking, type: :model do
  subject(:booking) { build(:booking) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to belong_to(:event) }

  describe "validations" do
    it "is invalid when event is in the past" do
      booking = build(:booking, event: create(:event, starts_at: 1.day.ago))

      expect(booking).not_to be_valid
      expect(booking.errors[:event]).to include("has already started")
    end
  end

  describe ".create_for!" do
    it "creates booking atomically under event lock" do
      event = create(:event, tickets_capacity: 10)
      user = create(:user)

      booking = described_class.create_for!(user: user, event: event, quantity: 3)

      expect(booking).to be_persisted
      expect(event.remaining_tickets).to eq(7)
    end
  end
end
