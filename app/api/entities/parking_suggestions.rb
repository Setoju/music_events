module Entities
  class ParkingSuggestions < Grape::Entity
    expose :provider, documentation: { type: "string", desc: "Parking data provider" } do |payload, _|
      payload[:provider] || payload["provider"]
    end

    expose :event_id, documentation: { type: "integer", desc: "Event identifier" } do |payload, _|
      payload[:event_id] || payload["event_id"]
    end

    expose :radius_meters, documentation: { type: "integer", desc: "Search radius used for the lookup" } do |payload, _|
      payload[:radius_meters] || payload["radius_meters"]
    end

    expose :suggestions, using: Entities::ParkingSuggestion, documentation: { type: "Entities::ParkingSuggestion", is_array: true, desc: "Nearby parking suggestions" } do |payload, _|
      payload[:suggestions] || payload["suggestions"] || []
    end
  end
end