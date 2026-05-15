class FetchWeatherJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |job, error|
    job.send(:persist_unexpected_error, job.arguments.first, error)
    raise error
  end

  def perform(event_id, booking_id = nil)
    event = Event.find(event_id)
    # Request forecast centered on the event start time (day of the event)
    result = WeatherProvider.fetch(event, event.starts_at)

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
  end

  private

  def persist_unexpected_error(event_id, error)
    # Persist the final failed attempt so the event context still reflects the
    # last known job outcome after retries are exhausted.
    Rails.logger.error("FetchWeatherJob unexpected error for event #{event_id}: #{error.class} #{error.message}\n#{error.backtrace&.first(5).join("\n")}")

    event = Event.find_by(id: event_id)
    return unless event

    event.ensure_context
    event.event_context.update(
      weather_status: 'failed',
      weather_error: error.message,
      weather_error_code: WeatherErrorMapper.map(error.message),
      weather_fetched_at: Time.current,
      expires_at: 24.hours.from_now
    )
  rescue => inner_error
    Rails.logger.error("FetchWeatherJob: failed to persist error for event #{event_id}: #{inner_error.class} #{inner_error.message}")
  end

  def log_provider_error(event, error_message)
    Rails.logger.warn("Weather provider error for event #{event.id}: #{error_message}")
  end
end