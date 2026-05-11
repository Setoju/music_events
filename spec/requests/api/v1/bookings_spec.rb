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
      expect(JSON.parse(response.body)["message"]).to include("Event has already started")
    end

    it "rejects booking when not enough tickets remain" do
      event = create(:event, starts_at: 2.days.from_now, tickets_capacity: 3)
      3.times { create(:booking, event: event) }

      post "/api/v1/events/#{event.id}/bookings", headers: headers

      expect(response).to have_http_status(409)
      expect(JSON.parse(response.body)["message"]).to include("No tickets available for this event")
    end

    it "rejects duplicate booking from the same user" do
      event = create(:event, starts_at: 2.days.from_now, tickets_capacity: 5)
      create(:booking, user: user, event: event)

      post "/api/v1/events/#{event.id}/bookings", headers: headers

      expect(response).to have_http_status(409)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("duplicate_booking")
      expect(body["message"]).to include("already booked")
    end
  end

  describe "DELETE /api/v1/events/:event_id/bookings" do
    let!(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns unauthorized without bearer token" do
      event = create(:event)

      delete "/api/v1/events/#{event.id}/bookings"

      expect(response).to have_http_status(:unauthorized)
    end

    it "cancels an existing booking for upcoming event" do
      event = create(:event, starts_at: 2.days.from_now)
      create(:booking, user: user, event: event)

      expect do
        delete "/api/v1/events/#{event.id}/bookings", headers: headers
      end.to change(Booking, :count).by(-1)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to eq("")
    end

    it "returns not found when current user has no booking for the event" do
      event = create(:event, starts_at: 2.days.from_now)

      delete "/api/v1/events/#{event.id}/bookings", headers: headers

      expect(response).to have_http_status(:not_found)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("booking_not_found")
      expect(body["message"]).to include("don't have a booking")
    end

    it "rejects cancellation when event has already started" do
      event = create(:event, starts_at: 2.days.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.minute.ago)

      delete "/api/v1/events/#{event.id}/bookings", headers: headers

      expect(response).to have_http_status(422)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("event_already_started")
      expect(body["message"]).to include("already started")
    end
  end

  describe "GET /api/v1/bookings" do
    let!(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns unauthorized without bearer token" do
      get "/api/v1/bookings"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns only current user bookings" do
      create(:booking, user: user)
      create(:booking)

      get "/api/v1/bookings", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(1)
    end

    it "returns bookings ordered by newest first" do
      older_booking = create(:booking, user: user, created_at: 2.hours.ago)
      newer_booking = create(:booking, user: user, created_at: 1.hour.ago)

      get "/api/v1/bookings", headers: headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |booking| booking["id"] }
      expect(ids.first(2)).to eq([ newer_booking.id, older_booking.id ])
    end
  end
end
