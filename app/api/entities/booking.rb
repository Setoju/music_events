module Entities
  class Booking < Grape::Entity
    expose :id
    expose :user_id
    expose :event_id
    expose :created_at
    expose :user, using: Entities::User
    expose :event, using: Entities::Event
  end
end
