class ScheduleWeatherFetchesJob < ApplicationJob
  queue_as :background

  def perform
    target_start = 24.hours.from_now
    target_end = 24.5.hours.from_now
    queued_events = 0

    Event.where(starts_at: target_start..target_end).find_each do |event|
      next if event.event_context&.weather_fetched_at.present?

      FetchWeatherJob.perform_later(event.id)
      queued_events += 1
      Rails.logger.info("Enqueued weather fetch for event #{event.id}")
    end

    Rails.logger.info("Scheduled weather fetches completed. Events queued: #{queued_events}")
  end
end
