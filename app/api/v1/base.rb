module V1
  class Base < Grape::API
    mount V1::Events
    mount V1::Artists
  end
end
