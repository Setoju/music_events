# External Integrations

**Analysis Date:** 2026-05-14

## APIs & External Services

**None Currently Integrated:**
- No third-party API services integrated (Stripe, Twilio, SendGrid, etc.)
- All features currently self-contained within the Rails application
- Future integrations available but not yet implemented

## Data Storage

**Databases:**
- PostgreSQL 9.5+
  - Connection: Configured in `config/database.yml`
  - Client: Rails Active Record with `pg` gem 1.1+
  - Development database: `music_events_development`
  - Test database: `music_events_test`
  - Production database: Via `DATABASE_URL` environment variable
  - Pooling: `RAILS_MAX_THREADS` setting (default 5 connections)

**File Storage:**
- **Local Filesystem** (current configuration)
  - Development: `storage/` directory
  - Test: `tmp/storage/` directory
  - Used for event images, artist photos, etc.
  - Implementation: Rails Active Storage

- **AWS S3** (commented, available for future use)
  - Configuration in `config/storage.yml` (commented out)
  - Credentials via Rails credentials: `credentials.dig(:aws, :access_key_id)`
  - Region: `us-east-1` (hardcoded in template)
  - Requires: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` in credentials

- **Google Cloud Storage** (commented, available for future use)
  - Requires: GCS credentials JSON keyfile
  - Configuration in `config/storage.yml` (commented out)

**Caching:**
- Solid Cache - Database-backed cache store
  - Uses PostgreSQL (production) or SQLite (development/test)
  - Table: Implicit via Solid Cache gem
  - Purpose: Rate limiter state, Rails cache operations
  - Max size: 256 MB per environment
  - No external cache service required

## Authentication & Identity

**Auth Provider:**
- Custom (in-house implementation)
  - Implementation location: `app/api/v1/auth.rb`
  - Service layer: `app/services/jwt_token.rb`

**Authentication Flow:**
1. Sign Up: Email + password → Create user with bcrypt-hashed password
2. Sign In: Email + password → Authenticate via bcrypt → Return JWT
3. API Requests: JWT token in `Authorization: Bearer <token>` header
4. Token Validation:
   - JWT decoding via `JwtToken.decode()` service
   - Payload extraction: `user_id`, `jti` (JWT ID), `exp` (expiration), `iat` (issued at)
   - Token revocation check via `RevokedJwtToken` model

**Security Mechanisms:**
- JWT Algorithm: HS256 (HMAC SHA-256)
- Secret Key: `Rails.application.secret_key_base` (from credentials)
- Default Expiration: 24 hours from issue time
- Token Revocation: Via `RevokedJwtToken` model (database entries)
- Password Requirements:
  - Minimum length: 9 characters
  - Minimum uppercase: 1 letter (A-Z)
  - Minimum lowercase: 1 letter (a-z)
  - Minimum digit: 1 number (0-9)
  - Minimum special: 1 character (!@#$%^&*()_+-=[]{}|;':"\\,.<>/?")
  - Validation: `PasswordStrengthValidator` via `password_strength` gem

**Password Storage:**
- Algorithm: bcrypt (Rails `has_secure_password`)
- Cost factor: Default bcrypt rounds (10)
- Model: `User` class with `has_secure_password` macro

## Authorization & Access Control

**Framework:**
- Pundit - Policy-based authorization
- Location: `app/policies/` directory
- All policies inherit from `ApplicationPolicy`

**Policy Structure:**
- `ApplicationPolicy` (`app/policies/application_policy.rb`):
  - Base policy for all resources
  - Tracks `user` and `record` context
  - Helper methods: `admin?`, `authenticated?`
  - Anonymous users: Represented by `GuestUser` (utility class)

- Resource Policies:
  - `EventPolicy` (`app/policies/event_policy.rb`) - Event access control
  - `ArtistPolicy` (`app/policies/artist_policy.rb`) - Artist access control
  - `BookingPolicy` (`app/policies/booking_policy.rb`) - Booking access control
  - `ReviewPolicy` (`app/policies/review_policy.rb`) - Review access control

**User Roles:**
- Enum: `role` column on User model
- Values:
  - `user` (0) - Standard user
  - `admin` (1) - Administrator
- Query method: `user.user?`, `user.admin?`

**Authorization Enforcement:**
- Location: `app/api/v1/helpers/auth_helpers.rb`
- Method: `authorize_record!(record, query)` via Pundit
- Applied in endpoint handlers before resource modification

## Security & Rate Limiting

**Rate Limiting:**
- Framework: Rack::Attack (`config/initializers/rack_attack.rb`)
- Cache store: Rails cache (Solid Cache backend)

**Rate Limit Rules:**
1. **Sign-Up Throttle:**
   - Limit: 5 attempts per hour per IP
   - Endpoint: `POST /api/v1/auth/sign_up`

2. **Sign-In Throttle (IP-based):**
   - Limit: 30 attempts per hour per IP
   - Endpoint: `POST /api/v1/auth/sign_in`

3. **Sign-In Throttle (Email-based):**
   - Limit: 3 attempts per 5 minutes per email
   - Purpose: Brute-force protection
   - Endpoint: `POST /api/v1/auth/sign_in`
   - Extraction: Email from request JSON body

4. **Global API Throttle:**
   - Limit: 60 requests per minute per IP
   - Applies to: All `/api/*` endpoints

5. **Abuse Blocklist:**
   - Allow2Ban filter for auth endpoints
   - Threshold: 15 failed attempts per hour
   - Ban duration: 24 hours (86400 seconds)
   - Response: 403 Forbidden when blocked

**Throttle Response (429):**
```json
{
  "message": "Too many requests. Please try again later.",
  "error_code": "rate_limit_exceeded",
  "status": 429
}
```

**Block Response (403):**
```json
{
  "message": "[Custom message]",
  "error_code": "blocked",
  "status": 403
}
```

## Monitoring & Observability

**Error Tracking:**
- Not currently configured
- Available tools in dev dependencies:
  - Brakeman - Static security scanning (runs at development/test time)
  - Bundler Audit - Gem vulnerability scanning (runs at development/test time)

**Logs:**
- Rails default logging
- Output location: `log/` directory
- Sensitive parameter filtering: `config/initializers/filter_parameter_logging.rb`
- Filtered parameters: `password`, `password_confirmation` (not logged in plain text)

**Metrics/APM:**
- Not currently integrated
- No external monitoring service connected

## CI/CD & Deployment

**Hosting:**
- Docker container deployment (Dockerfile provided)
- Deployment tool: Kamal (Kubernetes-lite orchestration)
- Configuration: `config/deploy.yml`

**CI Pipeline:**
- GitHub Actions or similar (not visible in codebase)
- Pre-commit hooks: Git hooks in `.githooks/pre-commit`
  - Runs: `bundle exec rspec --fail-fast`
  - Purpose: Prevent commits with failing tests

**Health Checks:**
- Puma: `/` endpoint returns health status
- Not explicitly configured but default Rails behavior

## CORS Configuration

**Cross-Origin Resource Sharing:**
- Framework: Rack CORS (rack-cors gem)
- Configuration: `config/initializers/cors.rb`
- Current setup:
  ```
  Origins: * (allow all)
  Headers: Accept any headers
  Methods: GET, POST, PUT, DELETE, OPTIONS
  ```
- Note: Unrestricted CORS in current configuration; should be scoped in production

## Background Jobs & Asynchronous Processing

**Job Queue:**
- Solid Queue - Database-backed ActiveJob adapter
- No external job service (Redis, RabbitMQ) required
- Configuration: `config/queue.yml`
- Processing:
  - Dispatchers: Polling interval 1 second, batch size 500
  - Workers: 3 threads per process, `JOB_CONCURRENCY` processes
  - Polling: 0.1 seconds per worker cycle

**Job Definition:**
- Base class: `ApplicationJob < ActiveJob::Base`
- Location: `app/jobs/` directory
- Queued via: `SomeJob.perform_later()` calls

## Action Cable (WebSockets)

**Real-Time Communication:**
- Framework: Rails Action Cable
- Adapter:
  - Development: Async (in-process)
  - Test: Test adapter
  - Production: Solid Cable (database-backed, cluster-safe)
- Channels: Application-defined channels (if any)
- Polling interval: 0.1 seconds (production)
- Message retention: 1 day (production)
- No external WebSocket service required

## Environment Configuration

**Required Environment Variables:**
- `DATABASE_URL` - PostgreSQL connection string (production)
- `RAILS_MASTER_KEY` - Encryption key for `config/credentials.yml.enc`
- `RAILS_ENV` - Environment: `development`, `test`, `production`

**Optional Environment Variables:**
- `RAILS_MAX_THREADS` - Thread pool size (default: 5)
- `JOB_CONCURRENCY` - Background job worker processes (default: 1)
- `WEB_CONCURRENCY` - Puma worker processes (default: 1)

**Secrets Location:**
- Encrypted credentials: `config/credentials.yml.enc`
- Decryption key: `RAILS_MASTER_KEY` environment variable
- AWS credentials (if enabled): Under `aws:` section in credentials

## API Error Schema

**Standard Error Response:**
```json
{
  "message": "Error description",
  "error_code": "error_code_identifier",
  "status": 400
}
```

**Common Error Codes:**
- `not_found` (404) - Resource not found
- `validation_error` (422) - Active Record validation failed
- `bad_request` (400) - Invalid request parameters
- `forbidden` (403) - Authorization failed (Pundit)
- `unauthorized` (401) - Authentication required or failed
- `rate_limit_exceeded` (429) - Rate limit throttled

---

*Integration audit: 2026-05-14*
