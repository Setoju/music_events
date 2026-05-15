module Entities
  class EventContext < Grape::Entity
    expose :weather_status, documentation: { type: "string", desc: "current|missing|failed" } do |context, _|
      if context.weather_status == "success" && context.weather_data.present? && context.weather_fresh?
        "current"
      elsif context.weather_status == "failed"
        "failed"
      else
        "missing"
      end
    end

    expose :weather_fetched_at, documentation: { type: "dateTime", desc: "ISO8601 timestamp or null" } do |context, _|
      context.weather_fetched_at&.utc&.iso8601
    end

    expose :weather_error_code, documentation: { type: "string", desc: "Canonical short error code or null" } do |context, _|
      context.respond_to?(:weather_error_code) ? context.weather_error_code : nil
    end

    expose :forecast, if: ->(context, _) { context.weather_status == "success" && context.weather_data.present? } do |context, _|
      context.weather_data
    end
  end
end
