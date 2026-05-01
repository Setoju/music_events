module Entities
  class Review < Grape::Entity
    expose :id
    expose :user_id
    expose :event_id
    expose :rating
    expose :comment
    expose :created_at
    expose :user, using: Entities::User
  end
end
