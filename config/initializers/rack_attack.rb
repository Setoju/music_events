class Rack::Attack
  # Configure cache store (using Rails.cache by default)
  cache.store = :rails_cache

  # Rate limit: 5 sign-up attempts per hour per IP
  throttle("auth/sign_up", limit: 5, period: 3600.seconds) do |request|
    if request.path == "/api/v1/auth/sign_up" && request.post?
      request.ip
    end
  end

  # Rate limit: 30 sign-in attempts per hour per IP
  throttle("auth/sign_in", limit: 30, period: 3600.seconds) do |request|
    if request.path == "/api/v1/auth/sign_in" && request.post?
      request.ip
    end
  end

  # Rate limit: 3 sign-in attempts per 5 minutes per email (brute force protection)
  throttle("auth/sign_in/email", limit: 3, period: 300.seconds) do |request|
    if request.path == "/api/v1/auth/sign_in" && request.post?
      # Extract email from body
      body = request.body.read
      request.body.rewind
      email = JSON.parse(body)["email"] rescue nil
      email&.downcase
    end
  end

  # Rate limit: 60 requests per minute per IP for all API endpoints
  throttle("api/global", limit: 60, period: 60.seconds) do |request|
    if request.path.start_with?("/api/")
      request.ip
    end
  end

  # Blocklist: prevent excessive requests
  blocklist("block_abuse") do |request|
    # Check if IP has exceeded rate limits
    Rack::Attack::Allow2Ban.filter("#{request.ip}/auth_abuse", limit: 15, period: 3600.seconds, bantime: 86400.seconds) do
      request.path.start_with?("/api/v1/auth") && request.post?
    end
  end

  # Custom responder for throttled requests (new API)
  Rack::Attack.throttled_responder = ->(request) do
    status = 429
    headers = { "Content-Type" => "application/json" }
    body = {
      message: "Too many requests. Please try again later.",
      error_code: "rate_limit_exceeded",
      status: status
    }.to_json

    [ status, headers, [ body ] ]
  end

  # Custom responder for blocked requests (new API)
  Rack::Attack.blocklisted_responder = ->(request) do
    status = 403
    headers = { "Content-Type" => "application/json" }
    body = {
      message: "Your IP has been temporarily blocked due to too many failed attempts. Please try again later.",
      error_code: "ip_blocked",
      status: status
    }.to_json

    [ status, headers, [ body ] ]
  end
end

# Disable Rack::Attack in test and development
Rack::Attack.enabled = false if Rails.env.test? || Rails.env.development?
