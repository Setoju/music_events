class FetchWeatherJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  def perform(event_id, booking_id = nil)
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
      if booking_id
        begin
          booking = Booking.find_by(id: booking_id)
          if booking
            booking.update!(last_weather_fetch_at: Time.current, weather_fetch_attempts_count: 0, last_weather_fetch_attempt_at: nil)
          end
        rescue => e
          Rails.logger.warn("FetchWeatherJob: failed to update booking #{booking_id} after successful fetch: #{e.class} #{e.message}")
        end
      end
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
  rescue StandardError => e
    # Ensure unexpected errors are logged and persisted to the event context so
    # we don't silently lose provider failures when jobs error out.
    Rails.logger.error("FetchWeatherJob unexpected error for event #{event_id}: #{e.class} #{e.message}\n#{e.backtrace&.first(5).join("\n")}")

    begin
      event = Event.find_by(id: event_id)
      if event
        event.ensure_context
        event.event_context.update(
          weather_status: 'failed',
          weather_error: e.message,
          weather_error_code: WeatherErrorMapper.map(e.message),
          weather_fetched_at: Time.current,
          expires_at: 24.hours.from_now
        )
      end
    rescue => inner_e
      Rails.logger.error("FetchWeatherJob: failed to persist error for event #{event_id}: #{inner_e.class} #{inner_e.message}")
    end
  end

  private

  def log_provider_error(event, error_message)
    Rails.logger.warn("Weather provider error for event #{event.id}: #{error_message}")
  end
end