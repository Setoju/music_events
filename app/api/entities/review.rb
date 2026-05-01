module Entities
  class Review < Grape::Entity
    expose :id, documentation: { type: "integer", desc: "Review identifier" }
    expose :user_id, documentation: { type: "integer", desc: "Review author identifier" }
    expose :event_id, documentation: { type: "integer", desc: "Reviewed event identifier" }
    expose :rating, documentation: { type: "integer", desc: "Star rating" }
    expose :comment, documentation: { type: "string", desc: "Review comment" }
    expose :created_at, documentation: { type: "dateTime", desc: "Review creation time" }
    expose :user,
           using: Entities::User,
           documentation: { type: "Entities::User", desc: "Review author" }
  end
end
