require "rails_helper"

RSpec.describe "Artists API", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }
  let(:admin_headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: admin.id)}" } }
  let(:user_headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

  describe "GET /api/v1/artists/:id/events" do
    let!(:artist) { create(:artist) }
    let!(:other_artist) { create(:artist) }

    let!(:upcoming_event) { create(:event, starts_at: 1.day.from_now) }
    let!(:later_upcoming_event) { create(:event, starts_at: 3.days.from_now) }
    let!(:past_event) { create(:event, starts_at: 2.days.ago) }
    let!(:other_artist_event) { create(:event, starts_at: 2.days.from_now) }

    before do
      create(:event_artist, artist:, event: upcoming_event)
      create(:event_artist, artist:, event: later_upcoming_event)
      create(:event_artist, artist:, event: past_event)
      create(:event_artist, artist: other_artist, event: other_artist_event)
    end

    it "returns only upcoming events for the selected artist ordered by starts_at" do
      get "/api/v1/artists/#{artist.id}/events"

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |event| event["id"] }
      expect(ids).to eq([ upcoming_event.id, later_upcoming_event.id ])
      expect(ids).not_to include(past_event.id, other_artist_event.id)
    end
  end

  describe "POST /api/v1/artists" do
    it "allows admin to create artist" do
      params = attributes_for(:artist)

      expect do
        post "/api/v1/artists", params: params, headers: admin_headers
      end.to change(Artist, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "forbids regular user from creating artist" do
      post "/api/v1/artists", params: attributes_for(:artist), headers: user_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /api/v1/artists/:id" do
    let!(:artist) { create(:artist, name: "Old Name", country: "Ukraine") }

    it "allows admin to update only provided fields" do
      put "/api/v1/artists/#{artist.id}", params: { name: "New Name" }, headers: admin_headers

      expect(response).to have_http_status(:ok)
      expect(artist.reload.name).to eq("New Name")
      expect(artist.country).to eq("Ukraine")
    end

    it "forbids regular user from updating artist" do
      put "/api/v1/artists/#{artist.id}", params: { name: "New Name" }, headers: user_headers

      expect(response).to have_http_status(:forbidden)
      expect(artist.reload.name).to eq("Old Name")
    end
  end

  describe "DELETE /api/v1/artists/:id" do
    let!(:artist) { create(:artist) }

    it "allows admin to delete artist" do
      expect do
        delete "/api/v1/artists/#{artist.id}", headers: admin_headers
      end.to change(Artist, :count).by(-1)

      expect(response).to have_http_status(:ok)
    end

    it "forbids regular user from deleting artist" do
      expect do
        delete "/api/v1/artists/#{artist.id}", headers: user_headers
      end.not_to change(Artist, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
