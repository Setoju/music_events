class JwtToken
  ALGORITHM = "HS256"
  DEFAULT_EXPIRATION = 24.hours

  class << self
    def encode(payload = {}, exp: DEFAULT_EXPIRATION.from_now, jti: SecureRandom.uuid, **claims)
      token_payload = payload.to_h.merge(claims).merge(exp: exp.to_i, iat: Time.current.to_i, jti: jti)
      JWT.encode(token_payload, secret_key, ALGORITHM)
    end

    def decode(token)
      return nil if token.blank?

      decoded_payload = JWT.decode(token, secret_key, true, algorithm: ALGORITHM).first
      decoded_payload.with_indifferent_access
    rescue JWT::DecodeError, JWT::ExpiredSignature, TypeError
      nil
    end

    private

    def secret_key
      Rails.application.secret_key_base
    end
  end
end
