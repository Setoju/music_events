module Entities
  class Event < Grape::Entity
    expose :id, documentation: { type: "integer", desc: "Event identifier" }
    expose :name, documentation: { type: "string", desc: "Event name" }
    expose :venue, documentation: { type: "string", desc: "Event venue" }
    expose :city, documentation: { type: "string", desc: "Event city" }
    expose :latitude, documentation: { type: "decimal", desc: "Venue latitude" }
    expose :longitude, documentation: { type: "decimal", desc: "Venue longitude" }
    expose :genre, documentation: { type: "string", desc: "Event genre" }
    expose :starts_at, documentation: { type: "dateTime", desc: "Event start time" }
    expose :ticket_price, documentation: { type: "decimal", desc: "Ticket price" }
    expose :tickets_capacity, documentation: { type: "integer", desc: "Total tickets available" }
    expose :remaining_tickets, documentation: { type: "integer", desc: "Tickets remaining" }
    expose :description, documentation: { type: "string", desc: "Event description" }
    expose :artists,
           using: Entities::Artist,
           documentation: { type: "Entities::Artist", is_array: true, desc: "Performing artists" }
    expose :weather,
           using: Entities::EventContext,
           if: ->(event, _) { event.event_context.present? },
           documentation: { type: "Entities::EventContext", desc: "Weather forecast data" } do |event|
      event.event_context
    end
  end
end
