require "rails_helper"

RSpec.describe ParkingProvider do
  let(:event) { build(:event, latitude: 40.7128, longitude: -74.0060) }

  describe ".fetch" do
    it "returns the nearest parking suggestions sorted by distance" do
      body = [
        {
          osm_type: "node",
          osm_id: 2,
          lat: "40.714",
          lon: "-74.005",
          category: "amenity",
          type: "parking",
          display_name: "Far Parking, New York, USA",
          name: "Far Parking",
          extratags: { capacity: "50" }
        },
        {
          osm_type: "node",
          osm_id: 1,
          lat: "40.713",
          lon: "-74.006",
          category: "amenity",
          type: "parking",
          display_name: "Near Parking, New York, USA",
          name: "Near Parking",
          extratags: { capacity: "20" }
        }
      ]

      stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
        .to_return(status: 200, body: body.to_json, headers: { "Content-Type" => "application/json" })

      result = described_class.fetch(event)

      expect(result[:success]).to be(true)
      expect(result[:data]["provider"]).to eq("nominatim")
      expect(result[:data]["suggestions"].map { |suggestion| suggestion[:name] }).to eq([ "Near Parking", "Far Parking" ])
      expect(result[:data]["suggestions"].first[:distance_meters]).to be <= result[:data]["suggestions"].last[:distance_meters]
    end

    it "returns an error when coordinates are missing" do
      event.latitude = nil

      result = described_class.fetch(event)

      expect(result).to eq(success: false, data: nil, error: "Missing coordinates")
    end

    it "returns an error for malformed JSON" do
      stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
        .to_return(status: 200, body: "not-json", headers: { "Content-Type" => "application/json" })

      result = described_class.fetch(event)

      expect(result).to eq(success: false, data: nil, error: "Invalid JSON response")
    end
  end
end