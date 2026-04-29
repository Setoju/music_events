require "rails_helper"

RSpec.describe "Bookings API", type: :request do
  describe "POST /api/v1/events/:event_id/bookings" do
    let!(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns unauthorized without bearer token" do
      event = create(:event)
      post "/api/v1/events/#{event.id}/bookings", params: { quantity: 1 }

      expect(response).to have_http_status(:unauthorized)
    end

    it "creates booking for upcoming event when tickets are available" do
      event = create(:event, starts_at: 2.days.from_now, tickets_capacity: 5)

      expect do
        post "/api/v1/events/#{event.id}/bookings", params: { quantity: 2 }, headers: headers
      end.to change(Booking, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["quantity"]).to eq(2)
      expect(event.reload.remaining_tickets).to eq(3)
    end

    it "rejects booking for past event" do
      event = create(:event, starts_at: 1.day.ago, tickets_capacity: 5)
      post "/api/v1/events/#{event.id}/bookings", params: { quantity: 1 }, headers: headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["error"]).to include("Event has already started")
    end

    it "rejects booking when not enough tickets remain" do
      event = create(:event, starts_at: 2.days.from_now, tickets_capacity: 3)
      create(:booking, event: event, quantity: 3)

      post "/api/v1/events/#{event.id}/bookings", params: { quantity: 1 }, headers: headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["error"]).to include("No more tickets available")
    end
  end

  describe "GET /api/v1/bookings" do
    let!(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns only current user bookings" do
      create(:booking, user: user)
      create(:booking)

      get "/api/v1/bookings", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end
end
