require "rails_helper"

RSpec.describe "Manual Weather Fetch API", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }
  let(:user_headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

  describe "POST /api/v1/events/:id/fetch_weather" do
    it "returns unauthorized for guests" do
      event = create(:event, starts_at: 3.days.from_now)

      post "/api/v1/events/#{event.id}/fetch_weather"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns forbidden if user has no booking" do
      event = create(:event, starts_at: 3.days.from_now)

      post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("not_booked")
    end

    it "rejects manual fetches outside the 7-day window" do
      event = create(:event, starts_at: 10.days.from_now)
      create(:booking, user: user, event: event)

      post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("fetch_window")
    end

    it "rejects manual fetches just outside the 7-day boundary" do
      event = create(:event, starts_at: 7.days.from_now + 1.minute)
      create(:booking, user: user, event: event)

      post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("fetch_window")
    end

    it "enforces once-per-day rate limit" do
      event = create(:event, starts_at: 3.days.from_now)
      booking = create(:booking, user: user, event: event)
      booking.update!(last_weather_fetch_at: 2.hours.ago)
      post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers

      expect(response).to have_http_status(429)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("fetch_rate_limited")
    end

    it "queues a fetch and records an attempt for valid requests" do
      event = create(:event, starts_at: 3.days.from_now)
      booking = create(:booking, user: user, event: event)

      expect do
        post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers
      end.to change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(1)

      expect(response).to have_http_status(:accepted)
      booking.reload
      expect(booking.weather_fetch_attempts_count).to eq(1)
      expect(booking.last_weather_fetch_attempt_at).to be_within(5.seconds).of(Time.current)
    end

    it "allows multiple attempts after failures up to the limit" do
      event = create(:event, starts_at: 3.days.from_now)
      booking = create(:booking, user: user, event: event, weather_fetch_attempts_count: 2, last_weather_fetch_attempt_at: 1.hour.ago)

      expect do
        post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers
      end.to change { ActiveJob::Base.queue_adapter.enqueued_jobs.size }.by(1)

      expect(response).to have_http_status(:accepted)
      booking.reload
      expect(booking.weather_fetch_attempts_count).to eq(3)
      expect(booking.last_weather_fetch_attempt_at).to be_within(5.seconds).of(Time.current)
    end

    it "blocks attempts after exceeding the limit within 24 hours" do
      event = create(:event, starts_at: 3.days.from_now)
      booking = create(:booking, user: user, event: event, weather_fetch_attempts_count: 3, last_weather_fetch_attempt_at: 2.hours.ago)

      post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers

      expect(response).to have_http_status(429)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("fetch_rate_limited")
    end

    it "allows manual fetch exactly at 7 days before event" do
      event = create(:event, starts_at: 7.days.from_now)
      create(:booking, user: user, event: event)

      post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers

      expect(response).to have_http_status(:accepted)
    end

    it "prevents fetching for other users' bookings" do
      event = create(:event, starts_at: 3.days.from_now)
      create(:booking, user: other_user, event: event)

      post "/api/v1/events/#{event.id}/fetch_weather", headers: user_headers

      expect(response).to have_http_status(:forbidden)
      body = JSON.parse(response.body)
      expect(body["error_code"]).to eq("not_booked")
    end
  end
end
