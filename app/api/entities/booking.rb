module Entities
  class Booking < Grape::Entity
    expose :id, documentation: { type: "integer", desc: "Booking identifier" }
    expose :user_id, documentation: { type: "integer", desc: "Booking user identifier" }
    expose :event_id, documentation: { type: "integer", desc: "Booked event identifier" }
    expose :created_at, documentation: { type: "dateTime", desc: "Booking creation time" }
    expose :user,
           using: Entities::User,
           documentation: { type: "Entities::User", desc: "Booked user" }
    expose :event,
           using: Entities::Event,
           documentation: { type: "Entities::Event", desc: "Booked event" }
  end
end
