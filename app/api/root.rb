class Root < Grape::API
  prefix "api"
  version "v1", using: :path
  format :json

  rescue_from ActiveRecord::RecordNotFound do |e|
    error!({ error: e.message }, 404)
  end

  rescue_from ActiveRecord::RecordInvalid do |e|
    error!({ error: e.message }, 422)
  end

  rescue_from Pundit::NotAuthorizedError do
    error!({ error: "Forbidden" }, 403)
  end

  mount V1::Base
end
