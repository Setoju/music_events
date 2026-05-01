module Entities
  class Artist < Grape::Entity
    expose :id, documentation: { type: "integer", desc: "Artist identifier" }
    expose :name, documentation: { type: "string", desc: "Artist name" }
    expose :genre, documentation: { type: "string", desc: "Primary genre" }
    expose :bio, documentation: { type: "string", desc: "Artist biography" }
    expose :country, documentation: { type: "string", desc: "Artist country" }
    expose :website, documentation: { type: "string", desc: "Artist website" }
  end
end
