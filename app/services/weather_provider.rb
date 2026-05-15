require 'json'

class WeatherProvider
  API_URL = 'https://api.open-meteo.com/v1/forecast'
  HOURLY_FIELDS = 'temperature_2m,precipitation_probability,weather_code,wind_speed_10m'.freeze

  class << self
    def fetch(event)
      return error_result('Missing coordinates') if event.latitude.blank? || event.longitude.blank?

      3.times do |attempt|
        response = request_client.get do |request|
          request.params['latitude'] = event.latitude
          request.params['longitude'] = event.longitude
          request.params['hourly'] = HOURLY_FIELDS
          request.params['timezone'] = 'auto'
          request.params['forecast_days'] = 7
        end

        return parse_response(response) if response.success?

        return error_result(http_error_message(response)) unless retryable_status?(response.status) && attempt < 2
      rescue JSON::ParserError
        return error_result('Invalid JSON response')
      rescue Faraday::TimeoutError => e
        next if attempt < 2

        return error_result("Timeout: #{e.message}")
      rescue Timeout::Error => e
        next if attempt < 2

        return error_result("Timeout: #{e.message}")
      rescue Faraday::ConnectionFailed => e
        if timeout_exception?(e)
          next if attempt < 2

          return timeout_error_result(e)
        end

        next if attempt < 2

        return error_result("Connection error: #{e.message}")
      end

      error_result('Unexpected: request failed')
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
                                   exceptions: [Faraday::TimeoutError, Faraday::ConnectionFailed],
                                   retry_statuses: [429, 500, 502, 503, 504]
        end
        faraday.response :follow_redirects
        faraday.response :logger if Rails.env.development?
        faraday.options.timeout = 5
        faraday.options.open_timeout = 5
        faraday.adapter Faraday.default_adapter
      end
    end

    def parse_response(response)
      payload = JSON.parse(response.body)
      hourly = payload['hourly'] || {}
      time = Array(hourly['time'])

      list = time.first(9).each_with_index.map do |timestamp, idx|
        {
          'time' => timestamp,
          'temperature_2m' => value_at(hourly, 'temperature_2m', idx),
          'precipitation_probability' => value_at(hourly, 'precipitation_probability', idx),
          'weather_code' => value_at(hourly, 'weather_code', idx),
          'wind_speed_10m' => value_at(hourly, 'wind_speed_10m', idx)
        }
      end

      success_result(
        {
          'provider' => 'open-meteo',
          'latitude' => payload['latitude'],
          'longitude' => payload['longitude'],
          'timezone' => payload['timezone'],
          'hourly_units' => payload['hourly_units'] || {},
          'list' => list
        }
      )
    end

    def http_error_message(response)
      parsed_body = JSON.parse(response.body)
      parsed_body['reason'].presence || parsed_body['message'].presence || "HTTP #{response.status}"
    rescue JSON::ParserError
      "HTTP #{response.status}"
    end

    def value_at(hourly, key, index)
      values = Array(hourly[key])
      values[index]
    end

    def response_from_exception(exception)
      exception.respond_to?(:response) ? exception.response : nil
    end

    def retryable_status?(status)
      [429, 500, 502, 503, 504].include?(status)
    end

    def timeout_exception?(exception)
      exception.message.include?('execution expired') || exception.cause.is_a?(Timeout::Error)
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