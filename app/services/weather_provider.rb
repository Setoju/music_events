require 'json'

class WeatherProvider
  API_URL = 'https://api.openweathermap.org/data/2.5/forecast'

  class << self
    def fetch(event)
      return error_result('Missing coordinates') if event.latitude.blank? || event.longitude.blank?
      return error_result('Missing API key') if api_key.blank?

      3.times do |attempt|
        response = request_client.get do |request|
          request.params['lat'] = event.latitude
          request.params['lon'] = event.longitude
          request.params['appid'] = api_key
          request.params['units'] = 'metric'
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
      payload['list'] = Array(payload['list']).first(9)
      success_result(payload)
    end

    def api_key
      ENV['OPENWEATHERMAP_API_KEY']
    end

    def http_error_message(response)
      parsed_body = JSON.parse(response.body)
      parsed_body['message'].presence || "HTTP #{response.status}"
    rescue JSON::ParserError
      "HTTP #{response.status}"
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