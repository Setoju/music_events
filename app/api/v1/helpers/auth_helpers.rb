module V1
  module Helpers
    module AuthHelpers
      def current_user
        return @current_user if defined?(@current_user)

        payload = current_token_payload
        @current_user = payload ? User.find_by(id: payload[:user_id]) : nil
      end

      def authenticate!
        return if current_user

        error_response = {
          message: "Authentication required",
          error_code: "unauthorized",
          status: 401
        }
        error!(error_response, 401)
      end

      def revoke_current_token!
        payload = current_token_payload
        unless payload
          error_response = {
            message: "Authentication required",
            error_code: "unauthorized",
            status: 401
          }
          error!(error_response, 401)
        end

        RevokedJwtToken.revoke!(jti: payload[:jti], exp: Time.at(payload[:exp].to_i))
      end

      def authorize_record!(record, query)
        Pundit.authorize(pundit_user, record, query)
      end

      private

      def pundit_user
        current_user || GuestUser.new
      end

      def current_token_payload
        return @current_token_payload if defined?(@current_token_payload)

        payload = JwtToken.decode(bearer_token)
        @current_token_payload =
          if payload && !RevokedJwtToken.revoked?(payload[:jti])
            payload
          else
            nil
          end
      end

      def bearer_token
        header = headers["Authorization"].to_s
        scheme, token = header.split(" ", 2)

        return if scheme.blank? || token.blank?
        return unless scheme.casecmp("Bearer").zero?

        token
      end
    end
  end
end
