require 'json'

class WeatherProvider
  API_URL = 'https://api.open-meteo.com/v1/forecast'
  HOURLY_FIELDS = 'temperature_2m,precipitation_probability,weather_code,wind_speed_10m'.freeze

  class << self
    def fetch(event, target_time = nil)
      return error_result('Missing coordinates') if event.latitude.blank? || event.longitude.blank?

      3.times do |attempt|
        Rails.logger.info("WeatherProvider: fetch attempt=#{attempt + 1} for event=#{event.id}") if defined?(Rails)
        response = request_client.get do |request|
          request.params['latitude'] = event.latitude
          request.params['longitude'] = event.longitude
          request.params['hourly'] = HOURLY_FIELDS
          request.params['timezone'] = 'auto'
          request.params['forecast_days'] = 7
        end

        return parse_response(response, target_time) if response.success?

        return error_result(http_error_message(response)) unless retryable_status?(response.status) && attempt < 2
      rescue JSON::ParserError => e
        Rails.logger.warn("WeatherProvider: JSON parse error: #{e.message}") if defined?(Rails)
        return error_result('Invalid JSON response')
      rescue Faraday::TimeoutError => e
        Rails.logger.warn("WeatherProvider: Faraday timeout (attempt=#{attempt + 1}): #{e.message}") if defined?(Rails)
        next if attempt < 2

        return error_result("Timeout: #{e.message}")
      rescue Timeout::Error => e
        Rails.logger.warn("WeatherProvider: Timeout::Error (attempt=#{attempt + 1}): #{e.message}") if defined?(Rails)
        next if attempt < 2

        return error_result("Timeout: #{e.message}")
      rescue Faraday::ConnectionFailed => e
        Rails.logger.warn("WeatherProvider: ConnectionFailed (attempt=#{attempt + 1}): #{e.message}") if defined?(Rails)
        if timeout_exception?(e)
          next if attempt < 2

          return timeout_error_result(e)
        end

        next if attempt < 2

        return error_result("Connection error: #{e.message}")
      rescue StandardError => e
        Rails.logger.error("WeatherProvider: unexpected error (attempt=#{attempt + 1}): #{e.class} #{e.message}\n#{e.backtrace&.first(5).join("\n")}") if defined?(Rails)
        return error_result("Unexpected error: #{e.message}")
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
        # Increase timeouts to tolerate slow provider responses in some regions
        faraday.options.timeout = 10
        faraday.options.open_timeout = 10
        faraday.adapter Faraday.default_adapter
      end
    end

    def parse_response(response, target_time = nil)
      payload = JSON.parse(response.body)
      hourly = payload['hourly'] || {}
      times = Array(hourly['time'])

      if target_time
        # For an event target_time, return the full day of hourly entries for that date
        # Align comparisons in UTC to be robust against timezone variations in tests
        target_date = target_time.to_time.utc.to_date
        parsed_times = times.map { |t| Time.parse(t).utc }
        indices = parsed_times.each_with_index.select { |tt, idx| tt.to_date == target_date }.map(&:last)

        if indices.any?
          start_idx = indices.min
          end_idx = indices.max
          slice = times[start_idx..end_idx] || []
          base_idx = start_idx
        else
          # fallback to first 24 hours (or available entries)
          slice = times.first(24)
          base_idx = 0
        end
      else
        slice = times.first(9)
        base_idx = 0
      end

      list = Array(slice).each_with_index.map do |timestamp, rel_idx|
        idx = base_idx + rel_idx
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