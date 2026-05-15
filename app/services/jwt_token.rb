class JwtToken
  ALGORITHM = "HS256"
  DEFAULT_EXPIRATION = 24.hours
  WHITELISTED_CLAIMS = %w[user_id email role].freeze

  class << self
    def encode(payload = {}, exp: DEFAULT_EXPIRATION.from_now, jti: SecureRandom.uuid, **claims)
      # Validate that all claims are whitelisted
      all_claims = payload.to_h.merge(claims)
      claim_keys = all_claims.keys.map(&:to_s)
      invalid_claims = claim_keys - WHITELISTED_CLAIMS
      raise ArgumentError, "Invalid token claims: #{invalid_claims.join(', ')}" if invalid_claims.any?

      token_payload = all_claims.merge(exp: exp.to_i, iat: Time.current.to_i, jti: jti)
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
