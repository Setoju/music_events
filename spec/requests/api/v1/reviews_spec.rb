require "rails_helper"

RSpec.describe "Reviews API", type: :request do
  describe "POST /api/v1/events/:event_id/reviews" do
    let!(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns unauthorized without bearer token" do
      event = create(:event, starts_at: 1.day.ago)
      post "/api/v1/events/#{event.id}/reviews", params: { rating: 4 }

      expect(response).to have_http_status(:unauthorized)
    end

    it "creates review for user that booked event" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)

      expect do
        post "/api/v1/events/#{event.id}/reviews", params: { rating: 5, comment: "Loved it" }, headers: headers
      end.to change(Review, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["rating"]).to eq(5)
    end

    it "rejects review if user has no booking for event" do
      event = create(:event, starts_at: 1.day.ago)
      post "/api/v1/events/#{event.id}/reviews", params: { rating: 4 }, headers: headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["message"]).to include("Only users with bookings can review this event")
    end

    it "rejects review for not-started event" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)

      post "/api/v1/events/#{event.id}/reviews", params: { rating: 4 }, headers: headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["message"]).to include("Review can be created only after the event starts")
    end

    it "rejects duplicate review from the same user" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)
      create(:review, user: user, event: event, rating: 5)

      post "/api/v1/events/#{event.id}/reviews", params: { rating: 4 }, headers: headers

      expect(response).to have_http_status(422)
      expect(JSON.parse(response.body)["message"]).to include("User has already reviewed this event")
    end
  end

  describe "PUT /api/v1/events/:event_id/reviews" do
    let!(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns unauthorized without bearer token" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)
      create(:review, user: user, event: event, rating: 4)

      put "/api/v1/events/#{event.id}/reviews", params: { rating: 5 }

      expect(response).to have_http_status(:unauthorized)
    end

    it "updates the user's review" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)
      review = create(:review, user: user, event: event, rating: 4, comment: "Good show")

      put "/api/v1/events/#{event.id}/reviews", params: { rating: 5, comment: "Excellent show" }, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(review.id)
      expect(body["rating"]).to eq(5)
      expect(body["comment"]).to eq("Excellent show")
      expect(review.reload.rating).to eq(5)
      expect(review.reload.comment).to eq("Excellent show")
    end

    it "returns not found when the user has not reviewed the event" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)

      put "/api/v1/events/#{event.id}/reviews", params: { rating: 5 }, headers: headers

      expect(response).to have_http_status(:not_found)
      expect(JSON.parse(response.body)["message"]).to include("Resource not found")
    end

    it "rejects invalid ratings on edit" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      event.update_column(:starts_at, 1.day.ago)
      create(:review, user: user, event: event, rating: 4)

      put "/api/v1/events/#{event.id}/reviews", params: { rating: 6 }, headers: headers

      expect(response).to have_http_status(400)
      body = JSON.parse(response.body)
      expect(body["message"]).to include("rating")
      expect(body["error_code"]).to eq("bad_request")
      expect(body["status"]).to eq(400)
    end
  end

  describe "GET /api/v1/events/:event_id/reviews" do
    let(:user) { create(:user) }
    let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

    it "returns event reviews without authentication" do
      event = create(:event)
      get "/api/v1/events/#{event.id}/reviews"

      expect(response).to have_http_status(:ok)
    end

    it "returns event reviews ordered by newest first" do
      event = create(:event, starts_at: 1.day.from_now)
      create(:booking, user: user, event: event)
      another_user = create(:user)
      create(:booking, user: another_user, event: event)
      event.update_column(:starts_at, 1.day.ago)

      older_review = create(:review, user: user, event: event, rating: 4, created_at: 2.hours.ago)
      newer_review = create(:review, user: another_user, event: event, rating: 5, created_at: 1.hour.ago)

      get "/api/v1/events/#{event.id}/reviews", headers: headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |review| review["id"] }
      expect(ids).to eq([ newer_review.id, older_review.id ])
    end
  end
end
