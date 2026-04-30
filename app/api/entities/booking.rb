module Entities
  class Booking < Grape::Entity
    expose :id
    expose :user_id
    expose :event_id
    expose :created_at
  end
end
