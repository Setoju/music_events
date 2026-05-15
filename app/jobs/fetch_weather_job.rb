class FetchWeatherJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(event_id)
    event = Event.find(event_id)
    result = WeatherProvider.fetch(event)

    event.ensure_context

    if result[:success]
      event.event_context.update!(
        weather_data: result[:data],
        weather_status: 'success',
        weather_fetched_at: Time.current,
        expires_at: 24.hours.from_now
      )
    else
      log_provider_error(event, result[:error])
      event.event_context.update!(
        weather_status: 'failed',
        weather_error: result[:error],
        weather_error_code: WeatherErrorMapper.map(result[:error]),
        weather_fetched_at: Time.current,
        expires_at: 24.hours.from_now
      )
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.info("Event #{event_id} deleted before weather fetch")
  end

  private

  def log_provider_error(event, error_message)
    Rails.logger.warn("Weather provider error for event #{event.id}: #{error_message}")
  end
end