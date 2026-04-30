require "rails_helper"

RSpec.describe "Events API", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:admin_headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: admin.id)}" } }
  let(:user_headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

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
    it "allows admin to create an event" do
      params = attributes_for(:event).merge(
        starts_at: 2.days.from_now.iso8601,
        latitude: 51.5074,
        longitude: -0.1278
      )

      expect do
        post "/api/v1/events", params: params, headers: admin_headers
      end.to change(Event, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq(params[:name])
      expect(body["city"]).to eq(params[:city])
      expect(body["latitude"].to_f).to be_within(0.0001).of(51.5074)
      expect(body["longitude"].to_f).to be_within(0.0001).of(-0.1278)
    end

    it "forbids regular user from creating an event" do
      post "/api/v1/events", params: attributes_for(:event), headers: user_headers

      expect(response).to have_http_status(:forbidden)
    end

    it "returns unauthorized for guest" do
      post "/api/v1/events", params: attributes_for(:event)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PUT /api/v1/events/:id" do
    let!(:event) { create(:event, name: "Old Name") }

    it "allows admin to update an event" do
      put "/api/v1/events/#{event.id}", params: { name: "New Name", latitude: 48.8566, longitude: 2.3522 }, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(event.reload.name).to eq("New Name")
      expect(event.reload.latitude.to_f).to be_within(0.0001).of(48.8566)
      expect(event.reload.longitude.to_f).to be_within(0.0001).of(2.3522)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq("New Name")
    end

    it "forbids regular user from updating an event" do
      put "/api/v1/events/#{event.id}", params: { name: "New Name" }, headers: user_headers

      expect(response).to have_http_status(:forbidden)
      expect(event.reload.name).to eq("Old Name")
    end
  end

  describe "DELETE /api/v1/events/:id" do
    let!(:event) { create(:event) }

    it "allows admin to delete an event" do
      expect do
        delete "/api/v1/events/#{event.id}", headers: admin_headers
      end.to change(Event, :count).by(-1)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["message"]).to eq("Event deleted successfully")
    end

    it "forbids regular user from deleting an event" do
      expect do
        delete "/api/v1/events/#{event.id}", headers: user_headers
      end.not_to change(Event, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
