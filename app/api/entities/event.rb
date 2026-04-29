module Entities
  class Event < Grape::Entity
    expose :id
    expose :name
    expose :venue
    expose :city
    expose :genre
    expose :starts_at
    expose :ticket_price
    expose :tickets_capacity
    expose :remaining_tickets
    expose :description
  end
end
