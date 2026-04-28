module Entities
  class Event < Grape::Entity
    expose :id
    expose :name
    expose :venue
    expose :city
    expose :genre
    expose :starts_at
    expose :ticket_price
    expose :description
  end
end
