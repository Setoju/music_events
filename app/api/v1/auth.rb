module V1
  class Auth < Grape::API
    helpers V1::Helpers::AuthHelpers

    resource :auth do
      desc "Register user and return bearer token"
      params do
        requires :email, type: String
        requires :password, type: String
        requires :password_confirmation, type: String
      end
      post :sign_up do
        user = User.create!(declared(params).merge(role: :user))
        status 201
        { token: JwtToken.encode(user_id: user.id), user: Entities::User.represent(user).as_json }
      end

      desc "Authenticate user and return new bearer token"
      params do
        requires :email, type: String
        requires :password, type: String
      end
      post :sign_in do
        user = User.find_by(email: params[:email].to_s.downcase.strip)
        error!({ error: "Invalid email or password" }, 401) unless user&.authenticate(params[:password])

        status 200
        { token: JwtToken.encode(user_id: user.id), user: Entities::User.represent(user).as_json }
      end

      desc "Return current authenticated user"
      get :me do
        authenticate!
        present current_user, with: Entities::User
      end

      desc "Return password strength requirements"
      get :password_requirements do
        {
          password_requirements: {
            minimum_length: PasswordStrengthValidator::MINIMUM_LENGTH,
            requirements: [
              "At least one uppercase letter (A-Z)",
              "At least one lowercase letter (a-z)",
              "At least one number (0-9)",
              "At least one special character (!@#$%^&*()_+-=[]{}|;':\"\\,.<>/?)"
            ]
          }
        }
      end

      desc "Logout by revoking current JWT"
      delete :logout do
        authenticate!
        revoke_current_token!
        { message: "Logged out successfully" }
      end
    end
  end
end
