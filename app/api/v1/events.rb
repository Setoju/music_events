module V1
  class Events < Grape::API
    resource :events do
      desc "List all upcoming events"
      params do
        optional :city, type: String, desc: "Filter by city"
        optional :genre, type: String, desc: "Filter by genre"
      end
      get do
        events = Event.upcoming
        events = events.by_city(params[:city]) if params[:city]
        events = events.by_genre(params[:genre]) if params[:genre]
        present events, with: Entities::Event
      end

      desc "Get a single event"
      params do
        requires :id, type: Integer
      end
      get ":id" do
        event = Event.find(params[:id])
        present event, with: Entities::Event
      end

      desc "Create an event"
      params do
        requires :name, type: String
        requires :venue, type: String
        requires :city, type: String
        requires :starts_at, type: DateTime
        optional :genre, type: String
        optional :ticket_price, type: BigDecimal
        optional :description, type: String
      end
      post do
        event = Event.create!(declared(params))
        present event, with: Entities::Event
      end

      desc "Update an event"
      params do
        requires :id, type: Integer
        optional :name, :venue, :city, :genre, :description, type: String
        optional :starts_at, type: DateTime
        optional :ticket_price, type: BigDecimal
      end
      put ":id" do
        event = Event.find(params[:id])
        event.update!(declared(params, include_missing: false).except("id"))
        present event, with: Entities::Event
      end

      desc "Delete an event"
      delete ":id" do
        Event.find(params[:id]).destroy!
        { message: "Event deleted successfully" }
      end
    end
  end
end
