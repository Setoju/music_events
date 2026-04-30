require "rails_helper"

RSpec.describe "Bookings API", type: :request do
  describe "POST /api/v1/events/:event_id/bookings" do
    let!(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns unauthorized without bearer token" do
      event = create(:event)
      post "/api/v1/events/#{event.id}/bookings"

      expect(response).to have_http_status(:unauthorized)
    end

    it "creates booking for upcoming event when tickets are available" do
      event = create(:event, starts_at: 2.days.from_now, tickets_capacity: 5)

      expect do
        post "/api/v1/events/#{event.id}/bookings", headers: headers
      end.to change(Booking, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["id"]).to be_present
      expect(event.reload.remaining_tickets).to eq(4)
    end

    it "rejects booking for past event" do
      event = create(:event, starts_at: 1.day.ago, tickets_capacity: 5)
      post "/api/v1/events/#{event.id}/bookings", headers: headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["error"]).to include("Event has already started")
    end

    it "rejects booking when not enough tickets remain" do
      event = create(:event, starts_at: 2.days.from_now, tickets_capacity: 3)
      3.times { create(:booking, event: event) }

      post "/api/v1/events/#{event.id}/bookings", headers: headers

      expect(response).to have_http_status(409)
      expect(JSON.parse(response.body)["error"]).to include("No tickets available for this event")
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
