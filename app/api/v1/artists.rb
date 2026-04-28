module V1
  class Artists < Grape::API
    resource :artists do
      desc "Get all artists"
      get do
        artists = Artist.all
        present artists, with: Entities::Artist
      end

      desc "Get an artist by ID"
      params do
        requires :id, type: Integer
      end
      get ":id" do
        artist = Artist.find(params[:id])
        present artist, with: Entities::Artist
      end

      desc "Create a new artist"
      params do
        requires :name, type: String
        requires :genre, type: String
        requires :bio, type: String
        requires :country, type: String
        optional :website, type: String
      end
      post do
        artist = Artist.new(
          name: params[:name],
          genre: params[:genre],
          bio: params[:bio],
          country: params[:country],
          website: params[:website]
        )
        if artist.save
          present artist, with: Entities::Artist
        else
          error!({ error: artist.errors.full_messages }, 422)
        end
      end

      desc "Update an existing artist"
      params do
        requires :id, type: Integer
        optional :name, type: String
        optional :genre, type: String
        optional :bio, type: String
        optional :country, type: String
        optional :website, type: String
      end
      put ":id" do
        artist = Artist.find(params[:id])
        if artist.update(declared(params, include_missing: false).except("id"))
          present artist, with: Entities::Artist
        else
          error!({ error: artist.errors.full_messages }, 422)
        end
      end

      desc "Delete an artist"
      params do
        requires :id, type: Integer
      end
      delete ":id" do
        artist = Artist.find(params[:id])
        if artist.destroy
          { message: "Artist deleted successfully" }
        else
          error!({ error: "Failed to delete artist" }, 422)
        end
      end

      route_param :id do
        desc "Get events for a specific artist"
        get "events" do
          artist = Artist.find(params[:id])
          events = artist.events.upcoming
          present events, with: Entities::Event
        end
      end
    end
  end
end
