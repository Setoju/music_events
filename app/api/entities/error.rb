module Entities
  class Error < Grape::Entity
    expose :message, documentation: { type: "string", desc: "Error message" }
    expose :code, as: :error_code, documentation: { type: "string", desc: "Error code" }
    expose :status, documentation: { type: "integer", desc: "HTTP status code" }
  end
end
