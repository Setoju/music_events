require "rails_helper"

RSpec.describe "Parking Suggestions API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

  describe "GET /api/v1/events/:id/parking_suggestions" do
    it "returns unauthorized for guests" do
      event = create(:event, starts_at: 3.days.from_now)

      get "/api/v1/events/#{event.id}/parking_suggestions"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns forbidden if the user has no booking" do
      event = create(:event, starts_at: 3.days.from_now)

      get "/api/v1/events/#{event.id}/parking_suggestions", headers: headers

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("not_booked")
    end

    it "returns parking suggestions for a booked user" do
      event = create(:event, starts_at: 3.days.from_now, latitude: 40.7128, longitude: -74.0060)
      create(:booking, user: user, event: event)

      nominatim_body = [
        {
          osm_type: "node",
          osm_id: 100,
          lat: "40.713",
          lon: "-74.0058",
          category: "amenity",
          type: "parking",
          display_name: "City Garage, New York, USA",
          name: "City Garage",
          extratags: { capacity: "120", access: "public" }
        }
      ]

      stub_request(:get, %r{nominatim\.openstreetmap\.org/search})
        .to_return(status: 200, body: nominatim_body.to_json, headers: { "Content-Type" => "application/json" })

      get "/api/v1/events/#{event.id}/parking_suggestions", headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["provider"]).to eq("nominatim")
      expect(body["event_id"]).to eq(event.id)
      expect(body["suggestions"]).to be_an(Array)
      expect(body["suggestions"].first["name"]).to eq("City Garage")
    end

    it "returns a lookup error when the event has no coordinates" do
      event = create(:event, starts_at: 3.days.from_now, latitude: nil, longitude: nil)
      create(:booking, user: user, event: event)

      get "/api/v1/events/#{event.id}/parking_suggestions", headers: headers

      expect(response).to have_http_status(:bad_gateway)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("parking_lookup_failed")
      expect(body["message"]).to include("Missing coordinates")
    end

    it "blocks other users from accessing the suggestions" do
      event = create(:event, starts_at: 3.days.from_now, latitude: 40.7128, longitude: -74.0060)
      create(:booking, user: other_user, event: event)

      get "/api/v1/events/#{event.id}/parking_suggestions", headers: headers

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("not_booked")
    end
  end
end