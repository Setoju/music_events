module V1
  class Events < Grape::API
    helpers V1::Helpers::AuthHelpers

    resource :events do
      desc "List all upcoming events",
           success: { code: 200, entity: Entities::Event, is_array: true }
      params do
        optional :city, type: String, desc: "Filter by city"
        optional :genre, type: String, desc: "Filter by genre"
      end
      get do
        authorize_record!(Event, :index?)
        events = Event.upcoming.with_booked_tickets_count.preload(:artists)
        events = events.by_city(params[:city]) if params[:city]
        events = events.by_genre(params[:genre]) if params[:genre]
        present events, with: Entities::Event
      end

      desc "List all past events",
         success: { code: 200, entity: Entities::Event, is_array: true }
      params do
        optional :city, type: String, desc: "Filter by city"
        optional :genre, type: String, desc: "Filter by genre"
      end
      get "past" do
        authorize_record!(Event, :index?)
        events = Event.past.with_booked_tickets_count.preload(:artists)
        events = events.by_city(params[:city]) if params[:city]
        events = events.by_genre(params[:genre]) if params[:genre]
        present events, with: Entities::Event
      end

      desc "Get a single event",
         success: { code: 200, entity: Entities::Event, is_array: false }
      params do
        requires :id, type: Integer
      end
      get ":id" do
        event = Event.with_booked_tickets_count.preload(:artists, :reviews).find(params[:id])
        authorize_record!(event, :show?)
        present event, with: Entities::Event
      end

      desc "Trigger a manual weather fetch for an event (booked users only).",
           success: { code: 202 }
      params do
        requires :id, type: Integer
      end
      post ":id/fetch_weather" do
        authenticate!

        event = Event.find(params[:id])

        booking = current_user.bookings.find_by(event_id: event.id)
        unless booking
          error_response = {
            message: "You must have a booking for this event to fetch weather",
            error_code: "not_booked",
            status: 403
          }
          error!(error_response, 403)
        end

        # only allow manual fetches within one week of event start
        if event.starts_at > 7.days.from_now || event.starts_at <= Time.current
          error_response = {
            message: "Manual weather fetch is allowed only within 7 days before the event",
            error_code: "fetch_window",
            status: 422
          }
          error!(error_response, 422)
        end

        # rate limit: if a successful fetch happened in the last 24 hours, block
        if booking.last_weather_fetch_at.present? && booking.last_weather_fetch_at > 24.hours.ago
          error_response = {
            message: "Manual weather fetch already performed within the last 24 hours",
            error_code: "fetch_rate_limited",
            status: 429
          }
          error!(error_response, 429)
        end

        # Allow multiple attempts after failures: allow up to 3 attempts within 24 hours
        max_attempts = 3
        if booking.last_weather_fetch_attempt_at.present? && booking.last_weather_fetch_attempt_at > 24.hours.ago
          if booking.weather_fetch_attempts_count >= max_attempts
            error_response = {
              message: "Too many manual fetch attempts within 24 hours",
              error_code: "fetch_rate_limited",
              status: 429
            }
            error!(error_response, 429)
          end
        end

        # record attempt timestamp and increment counter (reset if older than 24h)
        if booking.last_weather_fetch_attempt_at.nil? || booking.last_weather_fetch_attempt_at <= 24.hours.ago
          booking.update!(weather_fetch_attempts_count: 1, last_weather_fetch_attempt_at: Time.current)
        else
          booking.update!(weather_fetch_attempts_count: booking.weather_fetch_attempts_count + 1, last_weather_fetch_attempt_at: Time.current)
        end

        # enqueue job and pass booking id so the job can clear attempts on success
        FetchWeatherJob.perform_later(event.id, booking.id)

        status 202
        { message: "Weather fetch queued" }
      end

      desc "Create an event",
         success: { code: 201, entity: Entities::Event, is_array: false }
      params do
        requires :name, type: String
        requires :venue, type: String
        requires :city, type: String
        requires :starts_at, type: DateTime
        optional :genre, type: String
        optional :ticket_price, type: BigDecimal
        optional :description, type: String
        optional :tickets_capacity, type: Integer, values: 1..10_000
        optional :latitude, type: BigDecimal
        optional :longitude, type: BigDecimal
      end
      post do
        authenticate!
        authorize_record!(Event, :create?)
        event = Event.create!(declared(params))
        present event, with: Entities::Event
      end

      desc "Update an event",
         success: { code: 200, entity: Entities::Event, is_array: false }
      params do
        requires :id, type: Integer
        optional :name, :venue, :city, :genre, :description, type: String
        optional :starts_at, type: DateTime
        optional :ticket_price, type: BigDecimal
        optional :tickets_capacity, type: Integer, values: 1..10_000
        optional :latitude, type: BigDecimal
        optional :longitude, type: BigDecimal
      end
      put ":id" do
        authenticate!
        event = Event.find(params[:id])
        authorize_record!(event, :update?)
        event.update!(declared(params, include_missing: false).except("id"))
        present event, with: Entities::Event
      end

      desc "Delete an event"
      delete ":id" do
        authenticate!
        event = Event.find(params[:id])
        authorize_record!(event, :destroy?)
        event.destroy!
        { message: "Event deleted successfully" }
      end
    end
  end
end
