module V1
  class Bookings < Grape::API
    helpers V1::Helpers::AuthHelpers

    resource :events do
      route_param :event_id, type: Integer do
        resource :bookings do
          desc "Book tickets for an upcoming event",
               success: { code: 201, entity: Entities::Booking, is_array: false }
          post do
            authenticate!

            begin
              event = Event.find(params[:event_id])
              booking = Booking.create_for!(
                user: current_user,
                event: event
              )
            rescue Booking::DuplicateBooking
              error_response = {
                message: "You have already booked this event",
                error_code: "duplicate_booking",
                status: 409
              }
              error!(error_response, 409)
            rescue Booking::NoTicketsAvailable
              error_response = {
                message: "No tickets available for this event",
                error_code: "no_tickets_available",
                status: 409
              }
              error!(error_response, 409)
            rescue ActiveRecord::RecordNotUnique
              error_response = {
                message: "You have already booked this event",
                error_code: "duplicate_booking",
                status: 409
              }
              error!(error_response, 409)
            end

            status 201
            # Fetch with eager loading for response
            booking = Booking.includes(:user, :event).find(booking.id)
            present booking, with: Entities::Booking
          end

          desc "Cancel booking for an upcoming event"
          delete do
            authenticate!

            event = Event.find(params[:event_id])

            booking = current_user.bookings.find_by(event_id: event.id)
            if booking.nil?
              error_response = {
                message: "You don't have a booking for this event",
                error_code: "booking_not_found",
                status: 404
              }
              error!(error_response, 404)
            end

            if event.starts_at <= Time.current
              error_response = {
                message: "Cannot cancel booking for an event that has already started",
                error_code: "event_already_started",
                status: 422
              }
              error!(error_response, 422)
            end

            booking.destroy!

            status 204
          end
        end
      end
    end

    resource :bookings do
      desc "List current user bookings",
           success: { code: 200, entity: Entities::Booking, is_array: true }
      get do
        authenticate!
        authorize_record!(Booking, :index?)
        bookings = current_user.bookings.includes(:event, :user).order(created_at: :desc)
        present bookings, with: Entities::Booking
      end
    end
  end
end
