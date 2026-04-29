require "rails_helper"

RSpec.describe Event, type: :model do
  subject(:event) { build(:event) }

  it { is_expected.to have_many(:event_artists) }
  it { is_expected.to have_many(:artists).through(:event_artists) }
  it { is_expected.to have_many(:bookings) }
  it { is_expected.to have_many(:users).through(:bookings) }
  it { is_expected.to have_many(:reviews) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:venue) }
  it { is_expected.to validate_presence_of(:city) }
  it { is_expected.to validate_presence_of(:starts_at) }
  it { is_expected.to validate_numericality_of(:ticket_price).is_greater_than_or_equal_to(0).allow_nil }
  it { is_expected.to validate_numericality_of(:tickets_capacity).only_integer.is_greater_than(0) }

  describe ".upcoming" do
    let!(:past_event) { create(:event, starts_at: 2.days.ago) }
    let!(:later_event) { create(:event, starts_at: 3.days.from_now) }
    let!(:sooner_event) { create(:event, starts_at: 1.day.from_now) }

    it "returns only future events ordered by starts_at ascending" do
      expect(described_class.upcoming).to eq([sooner_event, later_event])
      expect(described_class.upcoming).not_to include(past_event)
    end
  end

  describe ".by_city" do
    let!(:kyiv_event) { create(:event, city: "Kyiv") }
    let!(:lviv_event) { create(:event, city: "Lviv") }

    it "returns only events from requested city" do
      expect(described_class.by_city("Kyiv")).to contain_exactly(kyiv_event)
      expect(described_class.by_city("Kyiv")).not_to include(lviv_event)
    end
  end

  describe ".by_genre" do
    let!(:rock_event) { create(:event, genre: "rock") }
    let!(:jazz_event) { create(:event, genre: "jazz") }

    it "returns only events from requested genre" do
      expect(described_class.by_genre("rock")).to contain_exactly(rock_event)
      expect(described_class.by_genre("rock")).not_to include(jazz_event)
    end
  end

  describe "#remaining_tickets" do
    let!(:event) { create(:event, tickets_capacity: 10) }

    before do
      create(:booking, event: event, quantity: 3)
      create(:booking, event: event, quantity: 2)
    end

    it "returns capacity minus booked quantity" do
      expect(event.remaining_tickets).to eq(5)
    end
  end
end
