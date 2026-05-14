module V1
  class Events < Grape::API
    helpers V1::Helpers::AuthHelpers

    resource :events do
      desc "List all upcoming events",
           success: { code: 200, entity: Entities::Event, is_array: true }
      params do
        optional :city, type: String, desc: "Filter by city"
        optional :genre, type: String, desc: "Filter by genre"
      end
      get do
        authorize_record!(Event, :index?)
        events = Event.upcoming.with_booked_tickets_count.preload(:artists)
        events = events.by_city(params[:city]) if params[:city]
        events = events.by_genre(params[:genre]) if params[:genre]
        present events, with: Entities::Event
      end

      desc "List all past events",
         success: { code: 200, entity: Entities::Event, is_array: true }
      params do
        optional :city, type: String, desc: "Filter by city"
        optional :genre, type: String, desc: "Filter by genre"
      end
      get "past" do
        authorize_record!(Event, :index?)
        events = Event.past.with_booked_tickets_count.preload(:artists)
        events = events.by_city(params[:city]) if params[:city]
        events = events.by_genre(params[:genre]) if params[:genre]
        present events, with: Entities::Event
      end

      desc "Get a single event",
         success: { code: 200, entity: Entities::Event, is_array: false }
      params do
        requires :id, type: Integer
      end
      get ":id" do
        event = Event.with_booked_tickets_count.preload(:artists, :reviews).find(params[:id])
        authorize_record!(event, :show?)
        present event, with: Entities::Event
      end

      desc "Create an event",
         success: { code: 201, entity: Entities::Event, is_array: false }
      params do
        requires :name, type: String
        requires :venue, type: String
        requires :city, type: String
        requires :starts_at, type: DateTime
        optional :genre, type: String
        optional :ticket_price, type: BigDecimal
        optional :description, type: String
        optional :tickets_capacity, type: Integer, values: 1..10_000
        optional :latitude, type: BigDecimal
        optional :longitude, type: BigDecimal
      end
      post do
        authenticate!
        authorize_record!(Event, :create?)
        event = Event.create!(declared(params))
        present event, with: Entities::Event
      end

      desc "Update an event",
         success: { code: 200, entity: Entities::Event, is_array: false }
      params do
        requires :id, type: Integer
        optional :name, :venue, :city, :genre, :description, type: String
        optional :starts_at, type: DateTime
        optional :ticket_price, type: BigDecimal
        optional :tickets_capacity, type: Integer, values: 1..10_000
        optional :latitude, type: BigDecimal
        optional :longitude, type: BigDecimal
      end
      put ":id" do
        authenticate!
        event = Event.find(params[:id])
        authorize_record!(event, :update?)
        event.update!(declared(params, include_missing: false).except("id"))
        present event, with: Entities::Event
      end

      desc "Delete an event"
      delete ":id" do
        authenticate!
        event = Event.find(params[:id])
        authorize_record!(event, :destroy?)
        event.destroy!
        { message: "Event deleted successfully" }
      end
    end
  end
end
