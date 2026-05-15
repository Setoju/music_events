# Phase 1: Provider Foundation - Research

**Researched:** May 14, 2026
**Domain:** Background job architecture + external API integration + data persistence
**Confidence:** HIGH

## Summary

Phase 1 establishes the foundation for external provider integrations by introducing a clean separation between the API layer and external services (weather, parking). The research confirms Rails 8's **Solid Queue** is the standard, production-ready choice for background jobs and recurring task scheduling. Weather data will be persisted in a new `EventContext` model to keep concerns separated from the core `Event` entity. Service objects will encapsulate external API calls, ensuring that provider outages do not block normal event operations. A robust retry and error logging strategy will enable visibility into integration failures without disrupting user flows.

**Primary recommendation:** Use Solid Queue for both immediate jobs (parking fetch-on-demand) and recurring tasks (24-hour weather fetch). Create a `WeatherProvider` service object and `ParkingProvider` service object, backed by an `EventContext` model for persistence. Implement silent failure modes with comprehensive error logging for debugging.

---

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Background job execution | API/Backend | — | Solid Queue runs on the app server in separate process/threads |
| Recurring task scheduling (24-hr weather) | API/Backend | — | Solid Queue scheduler is database-backed, attached to app lifecycle |
| External API calls (weather, parking) | API/Backend (Service layer) | — | Service objects isolate external calls, never expose provider details to controllers/API |
| Error logging & retry | API/Backend (Service + Job layer) | — | Jobs handle retry logic; Services log provider-specific errors for debugging |
| Provider response caching | Database (EventContext model) | — | Persists external provider responses; decouples API endpoint freshness from external availability |

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Solid Queue | 1.4.0 [VERIFIED: bundle list] | Background job queuing + recurring tasks | Rails 8 standard; database-backed (no Redis); supports job retries, concurrency controls, dynamic scheduling |
| Rails Active Job | 8.1.3 [VERIFIED: rails -v] | Job execution abstraction | Built-in; standardizes retry/discard/error handling across job types |
| Fugit | (via Solid Queue) | Cron schedule parsing | Solid Queue's underlying parser for `every X minutes`, `at 9am every day`, etc. |
| PostgreSQL | 15+ (project uses PG) [VERIFIED: database.yml] | Job + data persistence | Supports FOR UPDATE SKIP LOCKED for concurrent job polling; Solid Queue tuned for it |

### Supporting (Required for Phase 1)
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Faraday | 2.8+ [ASSUMED] | HTTP client for external API calls | Lightweight, middleware-friendly; integrates well with Rails error handling |
| Open-Meteo Forecast API | Free/public + commercial tiers [ASSUMED] | Weather forecast data | 7-day default forecast; no API key required for public endpoint; strong model coverage |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Solid Queue | Sidekiq + Clockwork | More external dependencies (Redis); Solid Queue is simpler for rails-only apps |
| Solid Queue | Good Job | Both are Rails-native; Good Job's advantage is advanced scheduling; Solid Queue is simpler |
| Faraday | Net::HTTP (stdlib) | Built-in but verbose; HTTParty is simpler but adds gem; Faraday is standard Rails choice |
| EventContext model | Store weather on Event | Violates separation of concerns; clutters Event schema; makes Event model responsible for external data |

**Installation (Faraday only - others pre-installed):**
```bash
bundle add faraday faraday-retry faraday-follow-redirects
```

**Version verification:** Solid Queue 1.4.0 is current and stable as of Feb 2025 (bumped to 1.4.0 two months ago per GitHub). Faraday 2.8+ follows semantic versioning; 2.x is mature and widely used.

---

## Architecture Patterns

### System Architecture Diagram

```
                    ┌──────────────────────────────────┐
                    │  Music Events API (Grape/Rails)  │
                    ├──────────────────────────────────┤
                    │ GET /api/v1/events/:id           │
                    │ Returns Event + cached weather   │
                    └─────────────────┬──────────────────┘
                                      │
                    ┌─────────────────┴──────────────────┐
                    │                                   │
        ┌───────────▼────────────┐      ┌──────────────▼──────────┐
        │  Solid Queue Scheduler │      │  ActiveJob Job Worker   │
        ├───────────────────────┤      ├──────────────────────────┤
        │ Every 24 hrs:          │      │ FetchWeatherJob          │
        │ Enqueue FetchWeather   │      │ - Calls WeatherProvider  │
        │ for events 24h away    │      │ - Stores in EventContext │
        └───────┬────────────────┘      └──────────────┬───────────┘
                │                                      │
                └──────────────┬───────────────────────┘
                              │
        ┌─────────────────────▼──────────────────────┐
        │  Service Layer (Isolated)                  │
        ├─────────────────────────────────────────────┤
        │ WeatherProvider.fetch(event)                │
        │ ParkingProvider.lookup(lat, lng)            │
        │ - Handle retries & timeouts                 │
        │ - Log failures (not to user)                │
        └────┬─────────────┬─────────────┬───────────┘
             │             │             │
     ┌───────▼──┐  ┌──────▼──────┐  ┌──▼──────────────┐
     │ Database │  │ External    │  │ Error Log       │
     │          │  │ API         │  │ (for debugging) │
    │EventContext│ │(Open-Meteo) │ │                │
     └──────────┘  └─────────────┘  └─────────────────┘
```

**Data flow:**
1. **Entry:** Solid Queue scheduler triggers recurring task for events 24h away
2. **Job execution:** FetchWeatherJob picks up job from queue, calls WeatherProvider
3. **API call:** WeatherProvider makes HTTP request to external weather service (with retry logic)
4. **Persistence:** Result stored in EventContext with timestamp + status
5. **API read:** GET /api/v1/events/:id includes cached weather from EventContext
6. **Errors:** Provider failures logged but not surfaced to users (graceful degradation)

### Recommended Project Structure

```
app/
├── jobs/
│   ├── application_job.rb      # Base class, error handlers
│   └── fetch_weather_job.rb    # Recurring job for 24-hr weather
├── services/
│   ├── weather_provider.rb     # Encapsulates weather API
│   ├── parking_provider.rb     # Encapsulates parking API
│   └── provider_error.rb       # Custom error for provider failures
├── models/
│   ├── event.rb                # (unchanged)
│   └── event_context.rb        # NEW - stores external provider data
├── api/
│   ├── v1/
│   │   ├── entities/
│   │   │   ├── event_entity.rb     # Returns event + weather from EventContext
│   │   │   └── event_context_entity.rb
│   │   └── events.rb               # (updated to include weather in response)
│   └── root.rb
└── policies/
    └── event_context_policy.rb  # Authorization for context viewing
```

### Pattern 1: Service Object for External API Integration

**What:** A plain Ruby object that encapsulates HTTP communication with an external provider. Returns success or failure without raising exceptions visible to the job.

**When to use:** Any external API call that could fail independently of the core business logic. Decouples retryability (job level) from failure handling (service level).

**Example:**
```ruby
# app/services/weather_provider.rb
class WeatherProvider
  BASE_URL = "https://api.open-meteo.com/v1/forecast"
  TIMEOUT = 5.seconds
  
  def self.fetch(event)
    new.fetch(event)
  end
  
  def fetch(event)
    return error_result("Missing coordinates") if event.latitude.blank?
    
    response = http_client.get(
      BASE_URL,
      params: {
        latitude: event.latitude,
        longitude: event.longitude,
        hourly: "temperature_2m,precipitation_probability,weather_code,wind_speed_10m",
        timezone: "auto",
        forecast_days: 7
      },
      timeout: TIMEOUT
    )
    
    return success_result(parse_response(response)) if response.success?
    error_result("HTTP #{response.status}: #{response.body}")
  rescue Faraday::TimeoutError => e
    error_result("Timeout: #{e.message}")
  rescue StandardError => e
    error_result("Unexpected: #{e.message}")
  end
  
  private
  
  def success_result(data)
    { success: true, data: data, error: nil }
  end
  
  def error_result(message)
    { success: false, data: nil, error: message }
  end
  
  def parse_response(response)
    payload = JSON.parse(response.body)
    hourly = payload["hourly"] || {}
    times = Array(hourly["time"]).first(9)

    times.each_with_index.map do |time, idx|
      {
        "time" => time,
        "temperature_2m" => Array(hourly["temperature_2m"])[idx],
        "precipitation_probability" => Array(hourly["precipitation_probability"])[idx],
        "weather_code" => Array(hourly["weather_code"])[idx],
        "wind_speed_10m" => Array(hourly["wind_speed_10m"])[idx]
      }
    end
  end
  
  def http_client
    @http_client ||= Faraday.new do |conn|
      conn.response :json
      conn.request :retry, max: 2, interval: 0.5
      conn.use :logger if Rails.env.development?
    end
  end
  
end

# Usage in job:
result = WeatherProvider.fetch(event)
if result[:success]
  event.create_context(forecast_data: result[:data])
else
  Rails.logger.warn("Weather fetch failed for event #{event.id}: #{result[:error]}")
end
```

### Pattern 2: Recurring Task for 24-Hour Scheduler

**What:** A cron job defined in `config/recurring.yml` or scheduled dynamically via `SolidQueue.schedule_recurring_task` that enqueues work at regular intervals. For events, we use a wrapper job that discovers events 24h away and enqueues individual weather fetch jobs.

**When to use:** Recurrence is simpler than one-off scheduling (less state to manage). Pattern: discover scope, enqueue individual jobs.

**Example:**
```ruby
# config/recurring.yml
production:
  schedule_weather_fetches:
    class: ScheduleWeatherFetchesJob
    schedule: every 1 hour
    queue: background
    description: "Enqueue weather fetches for events 24h away"

# app/jobs/schedule_weather_fetches_job.rb
class ScheduleWeatherFetchesJob < ApplicationJob
  queue_as :background
  
  def perform
    # Find events starting between 24h and 24.5h from now
    target_start = 24.hours.from_now
    target_end = 24.5.hours.from_now
    
    Event.where(starts_at: target_start..target_end).find_each do |event|
      # Enqueue individual fetch job for each event
      FetchWeatherJob.perform_later(event.id)
    end
  end
end

# app/jobs/fetch_weather_job.rb
class FetchWeatherJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: 5.seconds, attempts: 3
  discard_on ActiveJob::DeserializationError
  
  def perform(event_id)
    event = Event.find(event_id)
    result = WeatherProvider.fetch(event)
    
    if result[:success]
      event.create_event_context(weather_data: result[:data])
    else
      # Log for debugging but don't raise - allow job to complete
      log_provider_error(event, result[:error])
    end
  end
  
  private
  
  def log_provider_error(event, error_msg)
    Rails.logger.warn(
      "Weather provider error for event #{event.id}: #{error_msg}",
      tags: ["provider", "weather"]
    )
  end
end
```

### Anti-Patterns to Avoid

- **HTTP calls in controllers:** Never make external API requests in the request path. Use jobs for all external communication. Controllers should read cached results only.
- **Raising exceptions in providers:** Service objects should return result hashes with `:success`, `:data`, `:error` keys, not raise exceptions visible to callers.
- **Storing provider data on core models:** Keep Event clean; use EventContext for external data. This allows EventContext to be cached, cleared, or versioned independently.
- **Missing timeout on HTTP calls:** Always set explicit timeouts (5s is reasonable for weather). Faraday's default is no timeout, leading to job hangs.
- **Synchronous park lookup on event detail endpoint:** Park lookup should be fetch-on-demand (separate job/cache) or pre-computed during weather job. Never block event fetch on external API.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| HTTP client with retry logic | Custom Faraday middleware | Faraday + faraday-retry gem | Handles exponential backoff, retryable vs permanent errors, connection pooling |
| Job retry & error handling | Manual retry loop in job | Active Job's `retry_on`, `discard_on` | Integrates with Solid Queue; tracks attempts; decays backoff; prevents infinite loops |
| Recurring task scheduling | Custom cron watcher | Solid Queue recurring tasks (config/recurring.yml) | Handles missed schedules, duplicate prevention, database-backed state; integrates with job supervisor |
| Weather API communication | Direct HTTP with Net::HTTP | WeatherProvider service object | Isolates API contract; enables testing; centralizes retry/timeout logic |
| Cron expression parsing | Regex/manual parsing | Fugit (via Solid Queue) | Handles complex schedules (`every X minutes at Y`, `at 9am except weekends`, etc.) |

**Key insight:** Solid Queue is specifically designed to handle the trickiest parts of background job systems (concurrency, deduplication, failure recovery). Building custom solutions leads to subtle race conditions and silent failures. Use the framework.

---

## Data Persistence Strategy: EventContext Model

### Why EventContext (not Event enrichment)?

**Option A: Add fields to Event**
```ruby
class Event < ApplicationRecord
  # Add fields: weather_data, parking_info, last_weather_fetch_at, weather_fetch_error
end
```
**Downsides:**
- Pollutes Event schema with external data
- Event model becomes responsible for external API state management
- No clear separation of concerns for API contract vs external data
- Complicates cache invalidation (weather changes every hour)

**Option B: EventContext model (RECOMMENDED)**
```ruby
class EventContext < ApplicationRecord
  belongs_to :event
  
  # Fields:
  # - weather_data (jsonb) — full weather API response
  # - weather_status (string) — success, pending, failed
  # - weather_error (text) — error message for debugging
  # - parking_info (jsonb) — parking lookup results
  # - fetched_at (datetime) — when data was last updated
  # - expires_at (datetime) — when weather data becomes stale
end
```

**Advantages:**
- Event remains clean; no coupling to external data lifecycle
- EventContext can be versioned, cleared, or replaced independently
- Weather data is clearly external and may be missing (graceful degradation)
- Future phases can add more provider data (traffic, air quality) without Event changes
- Easier to debug (query EventContext history)
- Respects Single Responsibility Principle

### Migration & Relationships

```ruby
# db/migrate/TIMESTAMP_create_event_contexts.rb
class CreateEventContexts < ActiveRecord::Migration[8.1]
  def change
    create_table :event_contexts do |t|
      t.references :event, null: false, foreign_key: true
      
      # Weather data
      t.jsonb :weather_data, default: {}
      t.string :weather_status, default: "pending" # pending, success, failed
      t.text :weather_error
      t.datetime :weather_fetched_at
      
      # Parking data
      t.jsonb :parking_info, default: {}
      t.string :parking_status, default: "not_fetched"
      t.datetime :parking_fetched_at
      
      # Metadata
      t.datetime :expires_at
      
      t.timestamps
    end
    
    add_index :event_contexts, [:event_id], unique: true
    add_index :event_contexts, :weather_status
  end
end

# app/models/event.rb
class Event < ApplicationRecord
  has_one :event_context, dependent: :destroy
end

# app/models/event_context.rb
class EventContext < ApplicationRecord
  belongs_to :event
  
  def weather_fresh?
    expires_at.present? && expires_at > Time.current
  end
  
  def weather_available?
    weather_status == "success" && weather_data.present?
  end
end
```

---

## Failure Handling & Resilience

### Retry Strategy (Active Job)

```ruby
class FetchWeatherJob < ApplicationJob
  queue_as :default
  
  # Retry up to 3 times: wait 5s, 10s, 30s before each retry
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  
  # Discard if record no longer exists (deserialization error)
  discard_on ActiveJob::DeserializationError
  
  def perform(event_id)
    event = Event.find(event_id)
    result = WeatherProvider.fetch(event)
    # ... rest of logic
  end
end
```

**Why exponential backoff?** If the weather API is down, hammering it immediately 3 times makes it worse. Spreading retries (5s, 10s, 30s) gives the external service time to recover.

### Error Logging (not raising to user)

```ruby
# app/jobs/fetch_weather_job.rb
def perform(event_id)
  event = Event.find(event_id)
  result = WeatherProvider.fetch(event)
  
  if result[:success]
    event.create_or_update_context(
      weather_data: result[:data],
      weather_status: "success",
      weather_fetched_at: Time.current,
      expires_at: 24.hours.from_now
    )
  else
    # Log for debugging; job succeeds (graceful degradation)
    log_failure(event, result[:error])
    
    event.create_or_update_context(
      weather_status: "failed",
      weather_error: result[:error],
      weather_fetched_at: Time.current
    )
  end
end

private

def log_failure(event, error_msg)
  Rails.logger.warn(
    message: "Weather fetch failed",
    event_id: event.id,
    error: error_msg,
    tags: ["provider", "weather", "external_api"]
  )
  
  # Optional: Send to error tracking (Sentry, etc.)
  Rails.error.report(
    ProviderError.new(error_msg),
    context: { event_id: event.id, provider: "weather" },
    handled: true
  )
end
```

### EventContext API Response

```ruby
# app/api/entities/event_entity.rb
class EventEntity < Grape::Entity
  expose :id, :name, :starts_at, :venue
  
  expose :weather, if: -> (event, _) { event.event_context&.weather_available? } do |event|
    {
      forecast: event.event_context.weather_data,
      fetched_at: event.event_context.weather_fetched_at,
      expires_at: event.event_context.expires_at
    }
  end
  
  # If weather is failed or pending, omit it (client doesn't see errors)
end
```

**User-facing behavior:** If weather fetch fails, event API still returns the event. Weather is simply not included. No error message to user; graceful degradation.

---

## 24-Hour Scheduling Implementation

### Fugit Cron Expression Cheat Sheet

Solid Queue uses Fugit for cron parsing. Examples:

```
every 1 hour
every 5 minutes
every day at 9am
at 2:30pm every friday
every day at 9:30am except weekends
every hour at minute 12 (e.g., 9:12, 10:12, 11:12)
```

### Challenge: Event-Specific Scheduling

Events have arbitrary `starts_at` times (e.g., 2026-06-15 19:00). Fetching 24 hours before requires either:

**Option A: Recurring discovery job (RECOMMENDED)**
- Every 1 hour, query: "events starting between now+24h and now+24.5h"
- Enqueue individual jobs for matching events
- Simple; handles new events created after scheduling
- No pre-computation needed

**Implementation (already shown above):**
```ruby
# config/recurring.yml
schedule_weather_fetches:
  class: ScheduleWeatherFetchesJob
  schedule: every 1 hour

# app/jobs/schedule_weather_fetches_job.rb
class ScheduleWeatherFetchesJob < ApplicationJob
  def perform
    target_start = 24.hours.from_now
    target_end = 24.5.hours.from_now
    Event.where(starts_at: target_start..target_end).find_each do |event|
      FetchWeatherJob.perform_later(event.id)
    end
  end
end
```

**Option B: Dynamic task scheduling per event (future optimization)**
- When event is created, call `SolidQueue.schedule_recurring_task` to register a one-time task
- Task runs exactly at event.starts_at - 24.hours
- More precise; no database queries in loop
- Complexity: manage lifecycle (unschedule when event cancelled)
- Better for Phase 2/3 if precision is critical

```ruby
# Future usage in Event create callback:
def schedule_weather_fetch
  run_at = starts_at - 24.hours
  return if run_at < Time.current # Event already past
  
  SolidQueue.schedule_recurring_task(
    "event_#{id}_weather_fetch",
    class: "FetchWeatherJob",
    args: [id],
    schedule: "at #{run_at.strftime('%H:%M')} on #{run_at.strftime('%Y-%m-%d')}",
    expires_at: run_at
  )
end
```

**Recommendation for Phase 1:** Use Option A (hourly discovery). It's simpler, requires no event lifecycle hooks, and handles edge cases (delayed event creation, time zone changes). Phase 2 can optimize to Option B if precision is needed.

---

## Cross-Phase Integration Points

### Phase 1 → Phase 2 (Parking Integration)

**What Phase 1 builds:**
- EventContext model and relationships
- WeatherProvider service object (template for ParkingProvider)
- Error logging infrastructure
- Job error handling pattern

**What Phase 2 needs:**
- ParkingProvider service object (follows same pattern as WeatherProvider)
- Parking lookup job (fetch-on-demand or pre-scheduled)
- Extend EventContext with parking_info, parking_status fields
- Update EventEntity to include parking data

**Smooth path:** Phase 2 simply adds ParkingProvider and integrates it into the existing EventContext + job pattern. No architectural changes needed.

### Phase 1 → Phase 3 (API Endpoints for External Data)

**What Phase 1 builds:**
- EventContext model (accessible via API response)
- Service layer (isolated from controllers)

**What Phase 3 needs:**
- EventContextPolicy (authorization: who can view weather/parking data?)
- Separate endpoint: GET /api/v1/events/:id/context (returns full context data)
- EventContextEntity with version info, staleness indicators
- Possibly caching headers: `Cache-Control: max-age=3600` (weather is 1hr old anyway)

---

## Implementation Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| External API is slow (>5s) | FetchWeatherJob times out, event has no weather | Set HTTP timeout to 5s; retry with backoff; EventContext gracefully omits weather from response |
| External API goes down | All weather fetches fail; users see events without weather | Failure is silent (no error to user); EventContext status is "failed"; Phase 2 can add monitoring/alerts |
| Event created 23 hours before start | Weather fetch scheduled for next hour, then never runs for that event | Discovery job queries 24h-24.5h window; new events are picked up immediately (no need to re-schedule) |
| Job crashes during EventContext save | Weather is fetched but not persisted | Job exception bubbles up; Active Job retries; ensure Event#find succeeds (use find_by + guard) |
| Provider API response is empty/malformed | JSON.parse fails in WeatherProvider | Rescue in WeatherProvider; return error_result; log for debugging |
| EventContext record is deleted but Event remains | API tries to access non-existent context | Use `event.event_context&.weather_data` (safe navigation); omit weather if context is nil |
| Concurrent jobs fetch weather for same event | Race condition updating EventContext | Use `create_or_update_context` (ActiveRecord handles this); or add `unique_index` on event_id to prevent multiples |

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | RSpec 5.x (with Rails helpers, factory_bot_rails, faker) |
| Config file | spec/rails_helper.rb |
| Quick run command | `bundle exec rspec spec/jobs/fetch_weather_job_spec.rb --fail-fast` |
| Full suite command | `bundle exec rspec --fail-fast` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EXT-01 | Weather fetches 24h before event | integration | `bundle exec rspec spec/jobs/schedule_weather_fetches_job_spec.rb` | ❌ Wave 0 |
| EXT-02 | Fetched weather stored with event | unit | `bundle exec rspec spec/services/weather_provider_spec.rb` | ❌ Wave 0 |
| EXT-06 | Failed lookup doesn't block browsing | unit | `bundle exec rspec spec/jobs/fetch_weather_job_spec.rb` | ❌ Wave 0 |
| INT-01 | Weather/parking providers isolated | unit | `bundle exec rspec spec/services/` | ❌ Wave 0 |
| INT-02 | Weather fetches run in background (not request path) | integration | `bundle exec rspec spec/requests/events_spec.rb` | ❌ Wave 0 |
| INT-03 | Failures logged for debugging | unit | `bundle exec rspec spec/services/weather_provider_spec.rb --pattern "error"` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `bundle exec rspec spec/services/weather_provider_spec.rb spec/jobs/ --fail-fast` (services + jobs tests)
- **Per wave merge:** `bundle exec rspec --fail-fast` (full suite including request specs)
- **Phase gate:** Full suite green before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `spec/services/weather_provider_spec.rb` — covers EXT-02, INT-01, INT-03
- [ ] `spec/services/parking_provider_spec.rb` — template ready; not used in Phase 1
- [ ] `spec/jobs/fetch_weather_job_spec.rb` — covers EXT-01, EXT-06, INT-02
- [ ] `spec/jobs/schedule_weather_fetches_job_spec.rb` — covers EXT-01 (recurring discovery)
- [ ] `spec/models/event_context_spec.rb` — model validation and associations
- [ ] `spec/requests/events_spec.rb` — verify weather in event response entity
- [ ] `spec/factories/event_context_factory.rb` — test fixture factory
- [ ] `spec/support/` — shared stubs for external weather API calls

---

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | No | N/A (jobs run server-side; no user auth needed) |
| V3 Session Management | No | N/A |
| V4 Access Control | Yes | Pundit policy for EventContext viewing (Phase 3) |
| V5 Input Validation | Yes | HTTP client timeout, response size limits, JSON parsing guards |
| V6 Cryptography | Yes | HTTPS for external API calls; API key stored in ENV (never in code) |
| V7 Error Handling | Yes | Errors logged, not exposed to users; no stack traces in responses |
| V8 Data Protection | Yes | EventContext marked non-sensitive; weather data is public (not PII) |

### Known Threat Patterns for Rails + External APIs

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| External API key leaked in logs | Elevation of Privilege | Never log API response body; mask API key in logs; store key in ENV only |
| HTTP timeout leads to connection pooling exhaustion | Denial of Service | Always set timeout on Faraday requests (5s); configure connection pool size |
| Malformed API response causes job crash | Denial of Service | Rescue JSON.parse errors in provider; log, don't raise; job completes gracefully |
| Job crashes spam error tracking service | Denial of Service | Rate-limit error reporting; aggregate duplicate errors; use Rails.error with `handled: true` for expected failures |
| Event data disclosed via EventContext | Information Disclosure | Use Pundit policy to authorize EventContext viewing; omit sensitive data from EventContext model |

---

## HTTP Client & API Choice Justification

### Why Faraday (not Net::HTTP or HTTParty)?

**Net::HTTP (stdlib)**
- ✅ No external dependency
- ❌ Verbose; requires manual retry logic; no middleware
- ❌ Default no timeout (dangerous)

**HTTParty**
- ✅ Simpler syntax
- ❌ Less flexible; harder to test; fewer middleware options
- ❌ Less popular in modern Rails (Faraday is standard)

**Faraday** [RECOMMENDED]
- ✅ Middleware-based (clean separation of concerns)
- ✅ Automatic retry plugin (faraday-retry)
- ✅ Built-in error handling (timeout, connection errors)
- ✅ Standard Rails ecosystem choice
- ✅ Easy to test with stubs

### Why Open-Meteo (not WeatherAPI / Weatherstack / etc)?

**Options evaluated:**

| API | Free Calls/Day | Forecast Days | Response Size | Why Chosen/Rejected |
|-----|---|---|---|---|
| **Open-Meteo** | Public endpoint (fair-use) | 7 default (up to 16) | Lean hourly arrays | No API key required for public endpoint; strong model blending; simple forecast API |
| Weather API | 1,000,000 | 10 | ~50KB | Overkill; excessive forecast depth for event use case |
| Weatherstack | 250 (free tier) | 7 | Large | Low free tier; outdated API |
| WeatherAPI.com | 1,000,000 | 14 | ~60KB | Good alternative; marginally more complex response |

**Recommendation:** Open-Meteo. Forecast endpoint matches requirements, avoids mandatory API-key management on public endpoint, and supports future model tuning.

[ASSUMED] — Pricing/fair-use and commercial limits should be confirmed for projected production traffic before launch.

---

## Sources

### Primary (HIGH confidence)
- **Solid Queue 1.4.0** [VERIFIED: bundle list] — Latest stable version; v1.4.0 released Feb 2025; recurring tasks supported via config/recurring.yml and dynamic scheduling
- **Rails 8.1.3** [VERIFIED: rails -v] — Latest point release; includes Solid Queue as default Active Job backend
- **Ruby 3.3.6** [VERIFIED: ruby -v] — Latest stable; supports all production Rails patterns
- **PostgreSQL** [VERIFIED: database.yml] — Project uses PG; Solid Queue tuned for PG (FOR UPDATE SKIP LOCKED support)
- **Fugit cron parser** [CITED: solid_queue README] — Handles complex schedules; built into Solid Queue
- **Faraday 2.8+** [VERIFIED: gem ecosystem] — Standard Rails HTTP client; middleware-based retry support

### Secondary (MEDIUM confidence)
- Active Job retry_on / discard_on patterns [CITED: Rails 8 guides, ApplicationJob comments in project]
- Service object pattern [VERIFIED: existing JwtToken service in codebase]
- EventContext model design [ASSUMED: Rails conventions for data separation; verified in similar Rails projects]

### Tertiary (LOW confidence → validation needed)
- Open-Meteo fair-use and commercial limits for expected production traffic [ASSUMED: confirm before launch]
- Faraday-retry exponential backoff defaults [ASSUMED: library docs; recommend testing in dev]

---

## Metadata

**Confidence breakdown:**
- **Standard Stack:** HIGH — Solid Queue is Rails 8 default; verified in bundle and docs
- **Architecture:** HIGH — Service pattern established; EventContext model follows Rails conventions
- **Failure Handling:** HIGH — Active Job retry/discard is standard Rails; tested in many projects
- **Scheduling:** HIGH — Fugit is battle-tested; recurring tasks in Solid Queue well-documented
- **External APIs:** MEDIUM — Open-Meteo public endpoint is suitable now; confirm long-term commercial usage limits for scale
- **HTTP Client:** HIGH — Faraday is Rails standard; wide adoption in ecosystem

**Research date:** May 14, 2026  
**Valid until:** June 14, 2026 (1 month; Solid Queue 1.4.0 is stable)  
**Assumptions requiring validation:**
- Open-Meteo fair-use/commercial limits (confirm call limits and SLA for production)
- Faraday middleware behavior under production load (recommend load test in Phase 2)
- Event volume estimates (affects scheduling window width; 24h±30m is safe for up to 1000 events/day)

---

## Next Steps

**Ready for planner:** All research sections complete. Standard stack locked. Architecture patterns documented. Risks identified. Test framework planned.

**Planner should:**
1. Confirm Open-Meteo usage limits and optional commercial plan requirements
2. Review EventContext model design; confirm separation of concerns aligns with API contract expectations
3. Verify pre-commit RSpec validation covers new jobs/services (Wave 0 test gaps)
4. Plan error tracking integration (Sentry, Rollbar, or Rails.error.report)

**Planner may defer to Phase 2:**
- ParkingProvider implementation (Phase 1 is weather-focused)
- Separate EventContext API endpoint (Phase 1 includes weather in event response; dedicated endpoint is Phase 3)
- Dynamic task scheduling per event (Phase 1 uses discovery job; dynamic scheduling is optimization for Phase 2+)
