require "rails_helper"

RSpec.describe "Artists API", type: :request do
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

  describe "PUT /api/v1/artists/:id" do
    let!(:artist) { create(:artist, name: "Old Name", country: "Ukraine") }

    it "updates only provided fields" do
      put "/api/v1/artists/#{artist.id}", params: { name: "New Name" }

      expect(response).to have_http_status(:ok)
      expect(artist.reload.name).to eq("New Name")
      expect(artist.country).to eq("Ukraine")
    end
  end
end
