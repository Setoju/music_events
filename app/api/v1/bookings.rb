module V1
  class Bookings < Grape::API
    helpers V1::Helpers::AuthHelpers

    resource :events do
      route_param :event_id, type: Integer do
        resource :bookings do
          desc "Book tickets for an upcoming event"
          post do
            authenticate!

            event = Event.find(params[:event_id])

            if current_user.bookings.exists?(event_id: event.id)
              error!({ error: "You have already booked this event" }, 409)
            end

            if event.remaining_tickets <= 0
              error!({ error: "No tickets available for this event" }, 409)
            end

            begin
              booking = Booking.create_for!(
                user: current_user,
                event: event
              )
            rescue ActiveRecord::RecordNotUnique
              error!({ error: "You have already booked this event" }, 409)
            end

            status 201
            present booking, with: Entities::Booking
          end

          desc "Cancel booking for an upcoming event"
          delete do
            authenticate!

            event = Event.find(params[:event_id])

            booking = current_user.bookings.find_by(event_id: event.id)
            if booking.nil?
              error!({ error: "You don't have a booking for this event" }, 404)
            end

            if event.starts_at <= Time.current
              error!({ error: "Cannot cancel booking for an event that has already started" }, 422)
            end

            booking.destroy!

            status 204
          end
        end
      end
    end

    resource :bookings do
      desc "List current user bookings"
      get do
        authenticate!
        authorize_record!(Booking, :index?)
        bookings = current_user.bookings.order(created_at: :desc)
        present bookings, with: Entities::Booking
      end
    end
  end
end
