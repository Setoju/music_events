class Root < Grape::API
  prefix "api"
  version "v1", using: :path
  format :json

  rescue_from ActiveRecord::RecordNotFound do |e|
    error_response = {
      message: "Resource not found",
      error_code: "not_found",
      status: 404
    }
    error!(error_response, 404)
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    error_response = {
      message: e.record.errors.full_messages.join(", "),
      error_code: "validation_error",
      status: 422
    }
    error!(error_response, 422)
  end

  rescue_from Pundit::NotAuthorizedError do
    error_response = {
      message: "You are not authorized to perform this action",
      error_code: "forbidden",
      status: 403
    }
    error!(error_response, 403)
  end

  mount V1::Base
end
