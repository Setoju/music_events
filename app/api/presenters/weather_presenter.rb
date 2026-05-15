module Presenters
  class WeatherPresenter
    def initialize(event_context)
      @context = event_context
    end

    def as_json
      return nil unless @context

      {
        weather_status: status,
        weather_fetched_at: @context.weather_fetched_at&.utc&.iso8601,
        weather_error_code: @context.weather_error_code
      }
    end

    private

    def status
      return "current" if @context.weather_status == "success" && @context.weather_data.present? && @context.weather_fresh?
      return "failed" if @context.weather_status == "failed"
      "missing"
    end
  end
end
