require "rails_helper"

RSpec.describe Artist, type: :model do
  subject(:artist) { build(:artist) }

  it { is_expected.to have_many(:event_artists) }
  it { is_expected.to have_many(:events).through(:event_artists) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:genre) }
  it { is_expected.to validate_presence_of(:country) }
  it { is_expected.to validate_presence_of(:bio) }
  it { is_expected.to validate_length_of(:bio).is_at_least(10) }
  it { is_expected.to allow_value("https://example.com").for(:website) }
  it { is_expected.not_to allow_value("example.com").for(:website) }

  describe ".by_genre" do
    let!(:rock_artist) { create(:artist, genre: "rock") }
    let!(:jazz_artist) { create(:artist, genre: "jazz") }

    it "returns only artists from requested genre" do
      expect(described_class.by_genre("rock")).to contain_exactly(rock_artist)
      expect(described_class.by_genre("rock")).not_to include(jazz_artist)
    end
  end

  describe ".by_country" do
    let!(:ua_artist) { create(:artist, country: "Ukraine") }
    let!(:uk_artist) { create(:artist, country: "United Kingdom") }

    it "returns only artists from requested country" do
      expect(described_class.by_country("Ukraine")).to contain_exactly(ua_artist)
      expect(described_class.by_country("Ukraine")).not_to include(uk_artist)
    end
  end
end
