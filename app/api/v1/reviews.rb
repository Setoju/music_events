module V1
  class Reviews < Grape::API
    helpers V1::Helpers::AuthHelpers

    resource :events do
      route_param :event_id, type: Integer do
        resource :reviews do
          desc "List event reviews"
          get do
            authenticate!
            authorize_record!(Review, :index?)
            event = Event.find(params[:event_id])
            present event.reviews.order(created_at: :desc), with: Entities::Review
          end

          desc "Create review for event by a user with booking"
          params do
            requires :rating, type: String, values: Review.ratings.keys
            optional :comment, type: String
          end
          post do
            authenticate!
            authorize_record!(Review, :create?)

            event = Event.find(params[:event_id])
            review = Review.create!(
              user: current_user,
              event: event,
              rating: declared(params)[:rating],
              comment: declared(params)[:comment]
            )

            status 201
            present review, with: Entities::Review
          end
        end
      end
    end
  end
end
