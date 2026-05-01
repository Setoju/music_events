module Entities
  class Event < Grape::Entity
    expose :id
    expose :name
    expose :venue
    expose :city
    expose :latitude
    expose :longitude
    expose :genre
    expose :starts_at
    expose :ticket_price
    expose :tickets_capacity
    expose :remaining_tickets
    expose :description
    expose :artists, using: Entities::Artist
  end
end
