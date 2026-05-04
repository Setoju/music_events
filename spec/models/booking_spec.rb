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

    it "enforces uniqueness at the database level" do
      user = create(:user)
      event = create(:event)
      create(:booking, user: user, event: event)

      expect do
        Booking.insert_all!([ { user_id: user.id, event_id: event.id, created_at: Time.current, updated_at: Time.current } ])
      end.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end

  describe ".create_for!" do
    it "creates booking atomically under event lock" do
      event = create(:event, tickets_capacity: 10)
      user = create(:user)

      booking = described_class.create_for!(user: user, event: event)

      expect(booking).to be_persisted
      expect(event.remaining_tickets).to eq(9)
    end
  end
end
