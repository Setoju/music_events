module Entities
  class AuthResponse < Grape::Entity
    expose :token, documentation: { type: "string", desc: "Bearer JWT token" }
    expose :user, using: Entities::User, documentation: { type: "Entities::User", desc: "Authenticated user" }
  end
end
