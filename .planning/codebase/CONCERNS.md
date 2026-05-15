# Codebase Concerns

**Analysis Date:** 2026-05-14

## Security Boundaries

### CORS Configuration — All Origins Allowed

**Risk:** Critical security exposure

**Issue:** CORS middleware in [config/initializers/cors.rb](config/initializers/cors.rb) allows requests from any origin:
```ruby
allow do
  origins "*"
  resource "*", headers: :any, methods: %i[get post put delete options]
end
```

This enables cross-origin attacks where malicious websites can make authenticated API calls on behalf of users.

**Files:** `config/initializers/cors.rb`

**Current mitigation:** None

**Recommendation:** Restrict CORS to specific frontend domains. For production: `origins ENV['CORS_ORIGINS'].split(',')` with frontend URL(s) only. For development: use whitelist pattern.

---

### Artist Creation — Policy/Implementation Mismatch

**Risk:** High - unauthorized resource creation

**Issue:** [app/policies/artist_policy.rb](app/policies/artist_policy.rb) correctly restricts `create?` to admin-only, but [app/api/v1/artists.rb](app/api/v1/artists.rb) line 29 only calls `authenticate!`, not `authorize_record!`. Any authenticated user can create artists.

```ruby
post do
  authenticate!  # ← Only checks if user exists, not if admin
  authorize_record!(Artist, :create?)  # ← Policy is never enforced
  artist = Artist.new(...)
end
```

**Files:** `app/api/v1/artists.rb` (line 29-30)

**Impact:** Spam, data pollution, permission escalation vector

**Fix approach:** Ensure `authorize_record!(Artist, :create?)` is called BEFORE artist creation, or combine both checks into a guarding condition.

---

### Booking Overbooking Race Condition

**Risk:** High - data integrity violation

**Issue:** [app/api/v1/bookings.rb](app/api/v1/bookings.rb) checks remaining tickets before creation (lines 11-21), but this check happens outside the database lock:

```ruby
if event.remaining_tickets <= 0  # ← Read without lock
  error_response = { ... }
  error!(error_response, 409)
end

booking = Booking.create_for!(...)  # ← Lock acquired here, too late
```

Meanwhile, [app/models/booking.rb](app/models/booking.rb) uses pessimistic locking during write but not during read. If two concurrent requests arrive:
1. Both see remaining_tickets > 0
2. Both try to create bookings within the lock
3. One succeeds, the other gets unique constraint violation caught as "duplicate_booking"

This confuses clients and may allow overbooking if the constraint is not properly enforced at database level.

**Files:** `app/api/v1/bookings.rb` (lines 11-21), `app/models/booking.rb` (line 5)

**Impact:** Event overbooked beyond capacity, data inconsistency

**Fix approach:**
- Move remaining_tickets check inside `create_for!` transaction within the lock
- Or use SELECT ... FOR UPDATE before the check to serialize reads
- Document expected behavior for constraint violations

---

## Error Handling & Validation

### Inconsistent Error Response Construction

**Risk:** Medium - maintenance burden, potential incomplete handling

**Issue:** API endpoints construct error responses manually in some places and delegate to Grape's `error!` in others:

**Manual construction** (e.g., [app/api/v1/bookings.rb](app/api/v1/bookings.rb) lines 14-17):
```ruby
error_response = {
  message: "No tickets available for this event",
  error_code: "no_tickets_available",
  status: 409
}
error!(error_response, 409)
```

**Delegated to rescue handlers** (e.g., [app/api/root.rb](app/api/root.rb) lines 26-32):
```ruby
rescue_from ActiveRecord::RecordInvalid do |e|
  error_response = {
    message: e.record.errors.full_messages.join(", "),
    error_code: "validation_error",
    status: 422
  }
  error!(error_response, 422)
end
```

This duplication makes it hard to maintain consistent error contracts.

**Files:** `app/api/v1/bookings.rb`, `app/api/v1/reviews.rb`, `app/api/v1/artists.rb`, `app/api/root.rb`

**Recommendation:** Create a shared error response builder class or use Grape's built-in error entity (see `Entities::Error` in [app/api/entities/error.rb](app/api/entities/error.rb) if it exists).

---

### Missing String Length Validations

**Risk:** Low-Medium - data quality, potential DoS via large payloads

**Issue:** String fields lack maximum length constraints. Examples:

- **Event:** [app/models/event.rb](app/models/event.rb) validates name/venue/city/description but no max length
- **Artist:** [app/models/artist.rb](app/models/artist.rb) bio is text with minimum (10) but no maximum
- **Review:** [app/models/review.rb](app/models/review.rb) comment has no length constraints
- **User:** Email is not validated for length, only format

Large payloads in these fields could:
- Bloat database indices
- Slow API responses when serializing nested entities
- Enable denial of service via storage exhaustion

**Files:** `app/models/event.rb`, `app/models/artist.rb`, `app/models/review.rb`, `app/models/user.rb`

**Recommendation:** Add reasonable max lengths:
- Event name/venue: 255 chars
- Event description: 5000 chars
- Artist bio: 2000 chars
- Review comment: 2000 chars

---

### Latitude/Longitude Validation Asymmetry

**Risk:** Low - data integrity

**Issue:** [app/models/event.rb](app/models/event.rb) validates latitude/longitude individually as allow_nil:

```ruby
validates :latitude, numericality: { ... }, allow_nil: true
validates :longitude, numericality: { ... }, allow_nil: true
```

This allows events to have latitude but no longitude (or vice versa), creating incomplete geolocation data.

**Files:** `app/models/event.rb` (lines 10-11)

**Fix approach:** Add custom validation ensuring both are provided or both are nil:
```ruby
validate :coordinates_complete
```

---

### Website Validation Allows Invalid URIs

**Risk:** Low - data quality

**Issue:** [app/models/artist.rb](app/models/artist.rb) line 5 uses `URI.regexp(%w[http https])`, which has known limitations:
- May not catch invalid URIs with malformed domains
- Does not validate that the URI actually resolves
- Could allow URIs with embedded whitespace or special chars

**Files:** `app/models/artist.rb` (line 5)

**Recommendation:** Use a stricter validation or a dedicated gem like `validate_url`.

---

## Performance Bottlenecks

### N+1 Query Risk in Event Serialization

**Risk:** Medium - performance degradation at scale

**Issue:** [app/api/v1/events.rb](app/api/v1/events.rb) eagerly loads artists with `includes(:artists)` but the Grape entity [app/api/entities/event.rb](app/api/entities/event.rb) also exposes nested artists:

```ruby
expose :artists,
       using: Entities::Artist,
       ...
```

If an event has 50 artists, the entity iteration will make calls for each artist. However, the bigger issue is that **reviews** are included in the GET by ID but not specified in the scope:

```ruby
get ":id" do
  event = Event.includes(:artists, :reviews).find(params[:id])
  # ...
end
```

While this endpoint includes reviews, the list endpoint does NOT. If clients paginate through events and fetch each to get review counts, this causes N+1 queries.

**Files:** `app/api/v1/events.rb` (lines 5-7, 51)

**Impact:** API becomes slow as event count grows; 100 events = 100+ review queries

**Fix approach:**
- Add review count as computed field in Event entity (avoids SELECT * on reviews)
- Or use a counter cache on events table
- Document when reviews are available (full details only on GET by ID)

---

### Token Revocation Table Growth

**Risk:** Medium - database bloat, cleanup overhead

**Issue:** [app/models/revoked_jwt_token.rb](app/models/revoked_jwt_token.rb) creates a record for each logout, but there's no background job to delete expired tokens. The schema [db/schema.rb](db/schema.rb) has an index on `exp` but it's never used for cleanup.

With 10,000 active users logging out daily, the table will grow to 3.65 million rows/year with no maintenance.

**Files:** `app/models/revoked_jwt_token.rb`, database schema

**Impact:**
- Unchecked table growth
- Slower revocation lookups over time
- Storage costs

**Fix approach:** Add a Sidekiq/Solid Queue job to run daily:
```ruby
RevokedJwtToken.where("exp < ?", Time.current).delete_all
```

---

### Inefficient Booking Availability Check

**Risk:** Low - scaling concern

**Issue:** [app/models/event.rb](app/models/event.rb) line 26 computes remaining tickets via `bookings.count`:

```ruby
def remaining_tickets
  tickets_capacity - booked_tickets
end

def booked_tickets
  bookings.count  # ← SELECT COUNT(*) every time
```

This query runs on every booking request and scales linearly with booking count. For popular events, this can become a hot path.

**Files:** `app/models/event.rb` (lines 25-26), `app/api/v1/bookings.rb` (line 12)

**Fix approach:** Use SQL aggregation or counter cache:
- Option 1: Use `bookings.size` (cached in memory if already loaded)
- Option 2: Add `bookings_count` counter cache to events table (updates on each booking create/destroy)

---

## Technical Debt & Fragile Areas

### Rate Limiting Disabled in Development/Test

**Risk:** Medium - inadequate testing of security features

**Issue:** [config/initializers/rack_attack.rb](config/initializers/rack_attack.rb) line 68 disables Rack::Attack when not in production:

```ruby
Rack::Attack.enabled = false if Rails.env.test? || Rails.env.development?
```

This means:
- Developers cannot test rate limit behavior locally
- Tests don't cover the throttling logic
- Rate limit bypass bugs could ship to production undetected

**Files:** `config/initializers/rack_attack.rb` (line 68)

**Recommendation:**
- Keep Rack::Attack enabled in test environment
- Use a separate cache backend for tests to isolate rate limit state
- Add integration tests that verify rate limit thresholds are enforced

---

### Email Extraction from JSON Body in Rate Limiter

**Risk:** Low - reliability/maintainability

**Issue:** [config/initializers/rack_attack.rb](config/initializers/rack_attack.rb) lines 22-28 attempts to extract email from request body for per-email brute force protection:

```ruby
throttle("auth/sign_in/email", limit: 3, period: 300.seconds) do |request|
  if request.path == "/api/v1/auth/sign_in" && request.post?
    body = request.body.read
    request.body.rewind
    email = JSON.parse(body)["email"] rescue nil
    email&.downcase
  end
end
```

**Fragility:** If the request body format changes or parsing fails silently (rescue clause), the rate limiter will no longer group by email.

**Better approach:** Use a symmetric key that doesn't depend on body parsing (e.g., IP + endpoint combination is sufficient for brute force protection).

---

### Missing Test Coverage for Policy Boundaries

**Risk:** High - authorization bugs ship undetected

**Issue:** The test structure shows `spec/factories/`, `spec/models/`, and `spec/requests/` but no dedicated `spec/policies/` directory. This means Pundit authorization policies may lack explicit test coverage.

**Files:** `spec/` directory structure

**Impact:** Policy bugs like the artist creation issue above could go unnoticed.

**Fix approach:** Create comprehensive policy specs for each resource:
```ruby
# spec/policies/artist_policy_spec.rb
describe ArtistPolicy do
  describe '#create?' do
    context 'user is admin' do
      it { expect(policy).to permit(admin_user, Artist.new) }
    end
    
    context 'user is not admin' do
      it { expect(policy).not_to permit(user, Artist.new) }
    end
  end
end
```

---

### Review Delete Endpoint Authorization Gap

**Risk:** Medium - incomplete endpoint validation

**Issue:** [app/api/v1/reviews.rb](app/api/v1/reviews.rb) delete endpoint (lines 51-60) calls `authorize_record!(review, :destroy?)` but the policy check happens AFTER fetching the review:

```ruby
delete do
  authenticate!
  review = Review.includes(:user).find_by!(user_id: current_user.id, event_id: params[:event_id])
  authorize_record!(review, :destroy?)  # ← Policy check after fetch
  review.destroy
end
```

While functional, this could expose review existence via 404 vs 403 errors (timing attack). Better pattern: check authorization before accessing sensitive data.

**Files:** `app/api/v1/reviews.rb` (lines 51-60)

**Recommendation:** Reverse the order - check authorization based on current_user first, then fetch:
```ruby
authorize_record!(Review, :destroy?)  # Check class-level permissions
review = Review.includes(:user).find_by!(user_id: current_user.id, event_id: params[:event_id])
review.destroy
```

---

### JWT Token Payload Validation Gap

**Risk:** Medium - token injection/manipulation

**Issue:** [app/services/jwt_token.rb](app/services/jwt_token.rb) accepts arbitrary claims:

```ruby
def encode(payload = {}, exp: DEFAULT_EXPIRATION.from_now, jti: SecureRandom.uuid, **claims)
  token_payload = payload.to_h.merge(claims).merge(exp: exp.to_i, iat: Time.current.to_i, jti: jti)
  JWT.encode(token_payload, secret_key, ALGORITHM)
end
```

Callers could inject unexpected claims. If future code relies on payload content without validation, this is a vector for privilege escalation.

**Files:** `app/services/jwt_token.rb` (line 6)

**Fix approach:** Whitelist expected payload keys and validate/sanitize all inputs before encoding.

---

### Booking Validation Can Be Bypassed by Event Update

**Risk:** Medium - data inconsistency

**Issue:** [app/models/booking.rb](app/models/booking.rb) line 14 validates that the event is upcoming:

```ruby
def event_must_be_upcoming
  return if event.blank? || event.upcoming?
  errors.add(:event, "has already started")
end
```

But if an admin manually updates an event's `starts_at` to the past AFTER bookings are created, the bookings become invalid but are not cleaned up. The validation only runs on booking creation.

**Files:** `app/models/booking.rb`, `app/models/event.rb`

**Impact:** Ghost bookings for past events that can't be cancelled (validation prevents destruction via API)

**Fix approach:** Add a dependent callback on Event to cascade-delete bookings or prevent past-dating of started events.

---

## Missing Critical Features

### Event Ownership Not Enforced

**Risk:** High - data integrity

**Issue:** The [EventPolicy](app/policies/event_policy.rb) restricts update/destroy to admin-only, but doesn't track who created the event. Any admin can edit or delete any event, including those created by other admins. No audit trail exists.

**Files:** `app/models/event.rb`, `app/policies/event_policy.rb`

**Recommendation:** Add `created_by_user_id` to events table and implement creator-based policy rules for non-admin users. Add audit logging for event modifications.

---

### No Rate Limiting for Public List Endpoints

**Risk:** Medium - information disclosure via enumeration

**Issue:** The GET endpoints for events, artists, and reviews are rate-limited only by the global 60 req/min throttle. A malicious client could enumerate all resources via pagination to dump the database.

**Files:** `config/initializers/rack_attack.rb`

**Recommendation:** Add stricter rate limiting on list endpoints (e.g., 30 req/min per IP for /events).

---

### No Soft Delete for Cascading Deletions

**Risk:** Low-Medium - data loss, compliance

**Issue:** When an event is deleted, all associated bookings and reviews are destroyed via `dependent: :destroy`. There's no recovery mechanism or audit trail of deletions.

**Files:** `app/models/event.rb` (line 1-2)

**Recommendation:** Consider implementing paranoia gem for soft deletes, especially for events and reviews (potentially user-facing records).

---

## Edge Cases & Unhandled Scenarios

### Booking Cancellation After Event Started

**Issue:** [app/api/v1/bookings.rb](app/api/v1/bookings.rb) line 72 correctly prevents cancellation of past events, but the error message is generic. A user viewing their past bookings cannot distinguish between "already cancelled" vs "too late to cancel".

**Files:** `app/api/v1/bookings.rb` (line 72)

### Review Before Event Starts — Validator is Permissive

**Issue:** [app/models/review.rb](app/models/review.rb) line 25 validates `event.starts_at <= Time.current`, but this allows reviews to be created exactly when event starts. For instant events (starts_at = now), review validation is fragile to clock skew.

**Files:** `app/models/review.rb` (line 25)

### Duplicate Booking Detection Relies on Unique Constraint

**Issue:** [app/api/v1/bookings.rb](app/api/v1/bookings.rb) lines 10 and 40-44 use both application-level checks and database constraints for duplicate prevention:

```ruby
if current_user.bookings.exists?(event_id: event.id)  # Line 10
  error!(...)
end

# ... later ...

rescue ActiveRecord::RecordNotUnique  # Line 40
  error!(...)
end
```

This is correct but creates two error paths for the same condition. Clients see different responses depending on timing, which is confusing.

---

## Dependencies & Library Concerns

### JWT Gem - Standard Configuration

**Risk:** Low

**Status:** JWT library is correctly configured with symmetric signing (HS256). No detected issues.

---

### Grape Versioning - API Version Locked to v1

**Risk:** Low - forward compatibility concern

**Issue:** The API is versioned as v1 in path (`/api/v1/`), but there's no migration path for v2. If breaking changes are needed, the current routing structure makes it easy to mount V2 alongside V1.

**Files:** `app/api/root.rb` (line 2), `app/api/v1/base.rb` (line 1)

**Recommendation:** Document versioning strategy (URL path versioning is currently used; header-based versioning as alternative).

---

### Rack-Cors Gem - Correct Usage

**Risk:** Critical (separate issue documented above)

**Status:** Library is configured correctly for permissive CORS. The risk is in configuration choice, not usage.

---

## Database-Level Concerns

### Missing Foreign Key Constraint on Reviews

**Issue:** Reviews table has indexes on `user_id` and `event_id` but the schema [db/schema.rb](db/schema.rb) shows no explicit foreign key constraint (line 117-118 show bookings constraints, but reviews constraints are missing).

**Files:** `db/schema.rb`, `app/models/review.rb`

**Recommendation:** Verify all foreign keys are enforced at database level. Add migration:
```ruby
add_foreign_key :reviews, :users
add_foreign_key :reviews, :events
```

---

### Missing Indexes for Query Performance

**Issue:** Events table has indexes on `city`, `genre`, and `starts_at` but filtering is done via scopes without verification that indexes are used. No EXPLAIN ANALYZE output to confirm.

**Files:** `db/schema.rb`, `app/api/v1/events.rb` (lines 7-10)

---

### Revoked Token Cleanup Not Automated

**Risk:** Medium - performance degradation

**Issue:** Already noted above. RevokedJwtToken table will grow without cleanup.

---

## Summary of Priority Issues

| Priority | Issue | Category | Files |
|----------|-------|----------|-------|
| **Critical** | CORS allows all origins | Security | `config/initializers/cors.rb` |
| **High** | Artist creation not authorized | Security | `app/api/v1/artists.rb` |
| **High** | Booking overbooking race condition | Data Integrity | `app/api/v1/bookings.rb`, `app/models/booking.rb` |
| **High** | Missing policy test coverage | Testing | `spec/` structure |
| **Medium** | Inconsistent error handling | Code Quality | Multiple API endpoints |
| **Medium** | Token revocation table bloat | Performance | `app/models/revoked_jwt_token.rb` |
| **Medium** | Rate limiting disabled in test | Security | `config/initializers/rack_attack.rb` |
| **Medium** | N+1 queries in event serialization | Performance | `app/api/v1/events.rb` |
| **Low** | Missing string length validations | Data Quality | `app/models/` |
| **Low** | Coordinate validation asymmetry | Data Quality | `app/models/event.rb` |

---

*Concerns audit: 2026-05-14*
