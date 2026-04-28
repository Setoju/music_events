require "rails_helper"

RSpec.describe "Events API", type: :request do
  describe "GET /api/v1/events" do
    let!(:future_kyiv_rock) { create(:event, city: "Kyiv", genre: "rock", starts_at: 3.days.from_now) }
    let!(:future_lviv_jazz) { create(:event, city: "Lviv", genre: "jazz", starts_at: 4.days.from_now) }
    let!(:past_event) { create(:event, city: "Kyiv", genre: "rock", starts_at: 2.days.ago) }

    it "returns only upcoming events" do
      get "/api/v1/events"

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |event| event["id"] }
      expect(ids).to include(future_kyiv_rock.id, future_lviv_jazz.id)
      expect(ids).not_to include(past_event.id)
    end

    it "filters events by city and genre" do
      get "/api/v1/events", params: { city: "Kyiv", genre: "rock" }

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |event| event["id"] }
      expect(ids).to eq([ future_kyiv_rock.id ])
    end
  end

  describe "GET /api/v1/events/:id" do
    let!(:event) { create(:event) }

    it "returns a single event" do
      get "/api/v1/events/#{event.id}"

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["id"]).to eq(event.id)
      expect(body["name"]).to eq(event.name)
    end
  end

  describe "POST /api/v1/events" do
    it "creates an event" do
      params = attributes_for(:event).merge(starts_at: 2.days.from_now.iso8601)

      expect do
        post "/api/v1/events", params: params
      end.to change(Event, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq(params[:name])
      expect(body["city"]).to eq(params[:city])
    end
  end

  describe "PUT /api/v1/events/:id" do
    let!(:event) { create(:event, name: "Old Name") }

    it "updates an event" do
      put "/api/v1/events/#{event.id}", params: { name: "New Name" }

      expect(response).to have_http_status(:ok)
      expect(event.reload.name).to eq("New Name")
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("New Name")
    end
  end

  describe "DELETE /api/v1/events/:id" do
    let!(:event) { create(:event) }

    it "deletes an event" do
      expect do
        delete "/api/v1/events/#{event.id}"
      end.to change(Event, :count).by(-1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["message"]).to eq("Event deleted successfully")
    end
  end
end
