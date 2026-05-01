module Entities
  class User < Grape::Entity
    expose :id, documentation: { type: "integer", desc: "User identifier" }
    expose :email, documentation: { type: "string", desc: "User email address" }
    expose :role, documentation: { type: "string", desc: "User role" }
  end
end
