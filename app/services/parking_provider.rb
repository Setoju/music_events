require "json"

class ParkingProvider
  API_URL = "https://nominatim.openstreetmap.org/search"
  DEFAULT_RADIUS_METERS = 2000
  DEFAULT_LIMIT = 5

  class << self
    def fetch(event, radius_meters = DEFAULT_RADIUS_METERS, limit = DEFAULT_LIMIT)
      return error_result("Missing coordinates") if event.latitude.blank? || event.longitude.blank?

      3.times do |attempt|
        Rails.logger.info("ParkingProvider: fetch attempt=#{attempt + 1} for event=#{event.id}") if defined?(Rails)
        response = request_client.get do |request|
          request.params.merge!(query_params(event, radius_meters, limit))
        end

        return parse_response(response, event, radius_meters, limit) if response.success?

        return error_result(http_error_message(response)) unless retryable_status?(response.status) && attempt < 2
      rescue JSON::ParserError => e
        Rails.logger.warn("ParkingProvider: JSON parse error: #{e.message}") if defined?(Rails)
        return error_result("Invalid JSON response")
      rescue Faraday::TimeoutError => e
        Rails.logger.warn("ParkingProvider: Faraday timeout (attempt=#{attempt + 1}): #{e.message}") if defined?(Rails)
        next if attempt < 2

        return error_result("Timeout: #{e.message}")
      rescue Timeout::Error => e
        Rails.logger.warn("ParkingProvider: Timeout::Error (attempt=#{attempt + 1}): #{e.message}") if defined?(Rails)
        next if attempt < 2

        return error_result("Timeout: #{e.message}")
      rescue Faraday::ConnectionFailed => e
        Rails.logger.warn("ParkingProvider: ConnectionFailed (attempt=#{attempt + 1}): #{e.message}") if defined?(Rails)
        if timeout_exception?(e)
          next if attempt < 2

          return timeout_error_result(e)
        end

        next if attempt < 2

        return error_result("Connection error: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("ParkingProvider: unexpected error (attempt=#{attempt + 1}): #{e.class} #{e.message}\n#{e.backtrace&.first(5).join("\n")}") if defined?(Rails)
        return error_result("Unexpected error: #{e.message}")
      end

      error_result("Unexpected: request failed")
    end

    private

    def http_client
      @http_client ||= build_connection(include_retry: true)
    end

    def request_client
      @request_client ||= build_connection(include_retry: false)
    end

    def build_connection(include_retry:)
      Faraday.new(url: API_URL) do |faraday|
        if include_retry
          faraday.request :retry, max: 2, interval: 0.5, backoff_factor: 2,
                                   exceptions: [ Faraday::TimeoutError, Faraday::ConnectionFailed ],
                                   retry_statuses: [ 429, 500, 502, 503, 504 ]
        end
        faraday.response :follow_redirects
        faraday.response :logger if Rails.env.development?
        faraday.request :url_encoded
        faraday.options.timeout = 10
        faraday.options.open_timeout = 10
        faraday.adapter Faraday.default_adapter
      end
    end

    def query_params(event, radius_meters, limit)
      {
        format: "jsonv2",
        amenity: "parking",
        viewbox: viewbox_for(event, radius_meters),
        bounded: 1,
        limit: limit,
        addressdetails: 1,
        extratags: 1,
        namedetails: 1,
        dedupe: 1,
        "accept-language": "en"
      }
    end

    def parse_response(response, event, radius_meters, limit)
      payload = JSON.parse(response.body)
      suggestions = Array(payload).filter_map { |element| build_suggestion(element, event) }
        .sort_by { |suggestion| suggestion[:distance_meters] }
        .first(limit)

      success_result(
        {
          "provider" => "nominatim",
          "event_id" => event.id,
          "radius_meters" => radius_meters,
          "suggestions" => suggestions
        }
      )
    end

    def build_suggestion(element, event)
      latitude = element["lat"].to_f
      longitude = element["lon"].to_f
      return if latitude.blank? || longitude.blank?

      address = element["address"] || {}

      {
        name: element["name"].presence || element["display_name"].to_s.split(",").first.presence || "Parking",
        distance_meters: distance_meters(event.latitude, event.longitude, latitude, longitude),
        latitude: latitude,
        longitude: longitude,
        osm_type: element["osm_type"] || element["type"],
        osm_id: element["osm_id"] || element["id"],
        amenity: element["category"] || "parking",
        parking: element["type"],
        operator: element.dig("extratags", "operator"),
        capacity: element.dig("extratags", "capacity") || address["parking_capacity"],
        access: element.dig("extratags", "access") || address["access"]
      }
    end

    def viewbox_for(event, radius_meters)
      latitude_delta = radius_meters.to_f / 111_320.0
      longitude_delta = radius_meters.to_f / (111_320.0 * Math.cos(degrees_to_radians(event.latitude)))

      left = event.longitude.to_f - longitude_delta
      right = event.longitude.to_f + longitude_delta
      top = event.latitude.to_f + latitude_delta
      bottom = event.latitude.to_f - latitude_delta

      [ left, top, right, bottom ].join(",")
    end

    def distance_meters(lat1, lon1, lat2, lon2)
      earth_radius_meters = 6_371_000.0
      lat1 = lat1.to_f
      lon1 = lon1.to_f
      lat2 = lat2.to_f
      lon2 = lon2.to_f
      lat1_rad = degrees_to_radians(lat1)
      lat2_rad = degrees_to_radians(lat2)
      delta_lat = degrees_to_radians(lat2 - lat1)
      delta_lon = degrees_to_radians(lon2 - lon1)

      a = Math.sin(delta_lat / 2)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(delta_lon / 2)**2
      c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

      (earth_radius_meters * c).round
    end

    def degrees_to_radians(value)
      value.to_f * Math::PI / 180.0
    end

    def http_error_message(response)
      parsed_body = JSON.parse(response.body)
      parsed_body["error"].presence || parsed_body["message"].presence || parsed_body["remark"].presence || "HTTP #{response.status}"
    rescue JSON::ParserError
      "HTTP #{response.status}"
    end

    def retryable_status?(status)
      [ 429, 500, 502, 503, 504 ].include?(status)
    end

    def timeout_exception?(exception)
      exception.message.include?("execution expired") || exception.cause.is_a?(Timeout::Error)
    end

    def timeout_error_result(exception)
      error_result("Timeout: #{exception.message}")
    end

    def success_result(data)
      { success: true, data: data, error: nil }
    end

    def error_result(message)
      { success: false, data: nil, error: message }
    end
  end
end
