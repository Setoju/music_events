module Entities
  class ParkingSuggestion < Grape::Entity
    expose :name, documentation: { type: "string", desc: "Parking place name or label" } do |suggestion, _|
      suggestion[:name] || suggestion["name"]
    end

    expose :distance_meters, documentation: { type: "integer", desc: "Distance from the event in meters" } do |suggestion, _|
      suggestion[:distance_meters] || suggestion["distance_meters"]
    end

    expose :latitude, documentation: { type: "decimal", desc: "Parking latitude" } do |suggestion, _|
      suggestion[:latitude] || suggestion["latitude"]
    end

    expose :longitude, documentation: { type: "decimal", desc: "Parking longitude" } do |suggestion, _|
      suggestion[:longitude] || suggestion["longitude"]
    end

    expose :osm_type, documentation: { type: "string", desc: "OpenStreetMap element type" } do |suggestion, _|
      suggestion[:osm_type] || suggestion["osm_type"]
    end

    expose :osm_id, documentation: { type: "integer", desc: "OpenStreetMap element id" } do |suggestion, _|
      suggestion[:osm_id] || suggestion["osm_id"]
    end

    expose :amenity, documentation: { type: "string", desc: "OSM amenity tag" } do |suggestion, _|
      suggestion[:amenity] || suggestion["amenity"]
    end

    expose :parking, documentation: { type: "string", desc: "OSM parking tag" } do |suggestion, _|
      suggestion[:parking] || suggestion["parking"]
    end

    expose :operator, documentation: { type: "string", desc: "Operator tag" } do |suggestion, _|
      suggestion[:operator] || suggestion["operator"]
    end

    expose :capacity, documentation: { type: "string", desc: "Capacity tag" } do |suggestion, _|
      suggestion[:capacity] || suggestion["capacity"]
    end

    expose :access, documentation: { type: "string", desc: "Access tag" } do |suggestion, _|
      suggestion[:access] || suggestion["access"]
    end
  end
end
