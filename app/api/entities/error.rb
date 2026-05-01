module Entities
  class Error < Grape::Entity
    expose :message
    expose :code, as: :error_code
    expose :status
  end
end
