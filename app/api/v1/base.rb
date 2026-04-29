module V1
  class Base < Grape::API
    mount V1::Auth
    mount V1::Events
    mount V1::Artists
    mount V1::Bookings
    mount V1::Reviews
  end
end
