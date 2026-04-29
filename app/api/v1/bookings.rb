module V1
  class Bookings < Grape::API
    helpers V1::Helpers::AuthHelpers

    resource :events do
      route_param :event_id, type: Integer do
        resource :bookings do
          desc "Book tickets for an upcoming event"
          params do
            optional :quantity, type: Integer, default: 1, values: 1..20
          end
          post do
            authenticate!

            event = Event.find(params[:event_id])

            if current_user.bookings.exists?(event_id: event.id)
              error!({ error: "You have already booked this event" }, 409)
            end

            begin
              booking = Booking.create_for!(
                user: current_user,
                event: event,
                quantity: declared(params)[:quantity]
              )
            rescue ActiveRecord::RecordNotUnique
              error!({ error: "You have already booked this event" }, 409)
            end

            status 201
            present booking, with: Entities::Booking
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
