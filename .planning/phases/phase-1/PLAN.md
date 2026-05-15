# Phase 1: Provider Foundation — Executable Plan

**Phase Goal:** Build the integration layer that keeps external dependencies isolated from the rest of the API, enabling 24-hour advance weather fetches without blocking user operations.

**Scope:** Requirements EXT-01, EXT-02, EXT-06, INT-01, INT-02, INT-03

**Timeline:** 4 waves, estimated 2–3 days of focused development

---

## Phase Overview

### What This Phase Delivers

- **EventContext Model:** New data model to store external provider data (weather, parking) separately from Event
- **WeatherProvider Service:** Encapsulated HTTP client for Open-Meteo API with retry logic and error handling
- **Background Jobs:** FetchWeatherJob (fetches individual weather), ScheduleWeatherFetchesJob (discovers events 24h away)
- **Solid Queue Integration:** Database-backed job queue configured for recurring tasks
- **Test Infrastructure:** Factories, stubs, and comprehensive specs covering all provider integration patterns

### Why Separate Waves

1. **Wave 0 (Infrastructure):** Model and database layer must exist before any job or service can reference it
2. **Wave 1 (Service Layer):** WeatherProvider encapsulates external API logic; tested independently before job logic
3. **Wave 2 (Jobs & Scheduler):** Jobs depend on both EventContext and WeatherProvider; Solid Queue configured here
4. **Wave 3 (Integration Testing):** Cross-wave tests verify the complete flow works end-to-end; overlaps with Wave 2

### UAT Checklist (Phase Complete When All Pass)

- ✓ Faraday gem (2.8+) in Gemfile and bundle installs clean
- ✓ EventContext model created; migration runs without errors
- ✓ EventContext associations (belongs_to :event, has_one :event_context) work correctly
- ✓ WeatherProvider.fetch returns `{success: true, data: {...}}` for valid coordinates
- ✓ WeatherProvider.fetch returns `{success: false, error: "..."}` for API failures/timeouts
- ✓ FetchWeatherJob persists weather data to EventContext.weather_data with status "success"
- ✓ FetchWeatherJob marks EventContext.weather_status as "failed" when provider fails
- ✓ ScheduleWeatherFetchesJob enqueues FetchWeatherJob for events 24–24.5 hours away
- ✓ Failed weather fetches are logged to Rails.logger and don't crash the job
- ✓ EventEntity includes weather data from EventContext in API response (if available)
- ✓ RSpec full suite passes (all specs green, pre-commit gate satisfied)
- ✓ Solid Queue job supervisor starts and polls without errors in dev/test

---

## Wave 0: Infrastructure & Models

**Purpose:** Establish the data layer and HTTP client foundation that all subsequent waves depend on.

**Duration estimate:** 3–4 hours

**Dependencies:** None (clean slate)

**Success criteria (automated):**
- `bundle exec rspec spec/models/event_context_spec.rb` — All model tests pass
- `bundle exec rspec spec/factories/event_context_factory_spec.rb` — Factory builds valid instances
- `bundle exec rspec spec/support/weather_api_stubs_spec.rb` — Stub mocks work correctly
- Migration runs on dev/test databases without errors
- Faraday gem resolves without conflicts

---

### Task 0.1: Add Faraday Gem & Dependencies

**Files:** `Gemfile`, `Gemfile.lock`

**Action:** Add Faraday HTTP client and supporting gems to Gemfile. Faraday is the Rails standard for HTTP clients (middleware-based, retry support, timeout handling). Include:
- `faraday` (2.8+) — HTTP client
- `faraday-retry` — Automatic retry middleware
- `faraday-follow-redirects` — Follow HTTP redirects (some weather APIs redirect)

Add to development/test group:
- `vcr` — HTTP cassette recorder for stubbing external API calls in specs (optional but highly recommended)
- `webmock` — Mock HTTP requests during tests

Run `bundle install` to lock dependencies. Verify no conflicts with existing gems (esp. Rails ecosystem gems like ActiveSupport).

**Verify:**
```bash
bundle list | grep faraday
bundle list | grep webmock
bundle list | grep vcr
```

**Done:** `bundle install` completes without errors; `Gemfile.lock` includes Faraday 2.8+; `bundle list` shows all three gems present.

---

### Task 0.2: Create EventContext Model & Migration

**Files:** `app/models/event_context.rb`, `db/migrate/[timestamp]_create_event_contexts.rb`

**Action:** 

Create a new migration that adds the `event_contexts` table with the following fields:

**Columns:**
- `event_id` (references) — foreign key to events table, null: false, unique index (one context per event)
- `weather_data` (jsonb, default: {}) — normalized Open-Meteo API response (cached)
- `weather_status` (string, default: "pending") — one of: pending, success, failed
- `weather_error` (text) — error message from provider (for debugging, not user-facing)
- `weather_fetched_at` (datetime) — timestamp of last weather fetch attempt
- `expires_at` (datetime) — when weather data becomes stale (set to 24h from fetch time)
- `parking_info` (jsonb, default: {}) — placeholder for Phase 2
- `parking_status` (string, default: "not_fetched") — placeholder for Phase 2
- `parking_fetched_at` (datetime) — placeholder for Phase 2
- `created_at` (datetime) — automatic
- `updated_at` (datetime) — automatic

**Indexes:**
- Unique index on `event_id` (prevents multiple contexts per event)
- Index on `weather_status` (query efficiency: "find all pending weather fetches")

Create `app/models/event_context.rb` with:
- `belongs_to :event`
- Scopes: `scope :weather_pending, -> { where(weather_status: "pending") }`; `scope :weather_failed, -> { where(weather_status: "failed") }`
- Methods: `weather_fresh?` (checks if expires_at > Time.current); `weather_available?` (checks if success + data present)
- Validations: `validates :event_id, presence: true, uniqueness: true`

Update `app/models/event.rb` to add:
- `has_one :event_context, dependent: :destroy`
- Helper method: `def ensure_context` → calls `event_context || build_event_context`

**Verify:**
```bash
bundle exec rails db:migrate
bundle exec rspec spec/models/event_context_spec.rb
```

Expected tests to write:
- EventContext#weather_fresh? returns true when expires_at is in the future
- EventContext#weather_available? returns true only when status is "success" and weather_data is not empty
- Event#ensure_context creates context if missing
- Uniqueness constraint prevents duplicate contexts per event

**Done:** Migration runs clean; EventContext model validates correctly; Event ↔ EventContext associations work bidirectionally.

---

### Task 0.3: Create EventContext Factory & Test Support

**Files:** `spec/factories/event_context_factory.rb`, `spec/support/weather_api_stubs.rb`

**Action:**

**Factory (event_context_factory.rb):**
Create a FactoryBot factory for EventContext that:
- Associates with an Event (via trait or default)
- Provides sample weather data (frozen forecast from Open-Meteo schema)
- Supports trait `:with_weather` (success status, full data)
- Supports trait `:weather_failed` (failed status, error message)
- Supports trait `:weather_pending` (pending status, no data)

Example usage in specs: `create(:event_context, :with_weather)` or `create(:event_context, :weather_failed)`

**Test Support (weather_api_stubs.rb):**
Create a helper module that stubs Faraday HTTP calls to Open-Meteo:
- `stub_weather_success(lat, lng)` → returns mocked Open-Meteo response body
- `stub_weather_failure(lat, lng, error_code)` → returns mocked HTTP error (404, 500, timeout)
- `assert_weather_called_with(lat, lng)` → verifies HTTP call was made with correct params

Store sample API response as fixture in `spec/fixtures/weather_api_response.json` (real Open-Meteo response, sanitized).

This module should use `WebMock.stub_request` or `VCR.use_cassette` depending on preference (WebMock is simpler for unit tests; VCR is better for integration).

**Verify:**
```bash
bundle exec rspec spec/factories/ --fail-fast
# Test that factory builds valid instances without database hits in isolation
```

**Done:** Factory builds EventContext with associated Event; stubs work correctly (HTTP mocks receive requests and respond as expected).

---

### Task 0.4: Write EventContext Model Specs

**Files:** `spec/models/event_context_spec.rb`

**Action:** Write comprehensive specs covering:

**Associations & Validation:**
- `belongs_to :event` — context cannot exist without event
- `event_id` uniqueness constraint — two contexts cannot reference same event
- Associations valid when event exists

**Scopes:**
- `EventContext.weather_pending` — filters to pending status only
- `EventContext.weather_failed` — filters to failed status only

**Instance Methods:**
- `weather_fresh?` — returns true when expires_at > Time.current; false otherwise
- `weather_available?` — returns true only when status="success" AND weather_data is not empty object

**Callbacks:**
- Event dependent: destroy removes associated EventContext

Each test should be focused (one behavior per test), use factory to build instances, and use clear assertions.

Example spec names:
- "has_one association" ✓ or ✗
- "validates event_id presence" ✓ or ✗
- "enforces unique event_id" ✓ or ✗
- "weather_fresh? true when expires_at in future" ✓ or ✗
- "weather_available? true only when status success and data present" ✓ or ✗

**Verify:**
```bash
bundle exec rspec spec/models/event_context_spec.rb -v
```

All tests should pass; coverage should be >90% for the model.

**Done:** All EventContext model specs pass; model behavior is fully tested and documented.

---

## Wave 1: Service Layer

**Purpose:** Implement the HTTP client (WeatherProvider) that fetches weather from external API with robust error handling, retries, and timeouts.

**Duration estimate:** 4–5 hours

**Dependencies:** Wave 0 complete (Faraday gem installed; EventContext model exists but not used yet)

**Success criteria (automated):**
- `bundle exec rspec spec/services/weather_provider_spec.rb` — All provider tests pass
- HTTP calls properly timeout (5s) and don't hang
- Retries work: failed requests are retried; success after retry is captured
- Error results don't raise exceptions

---

### Task 1.1: Implement WeatherProvider Service Object

**Files:** `app/services/weather_provider.rb`, `app/services/provider_error.rb`

**Action:**

Create `WeatherProvider` service object that:

**Core Interface:**
- `WeatherProvider.fetch(event)` — class method that returns `{success: true, data: {...}}` or `{success: false, error: "..."}`
- Takes Event object as input; accesses `event.latitude`, `event.longitude`
- Never raises exceptions; always returns result hash

**HTTP Client Setup:**
- Use Faraday with timeout = 5 seconds
- Add `faraday-retry` middleware with max 2 retries, exponential backoff (0.5s intervals)
- Parse JSON responses automatically
- Log requests/responses in development mode (via `conn.use :logger`)

**API Integration:**
- Open-Meteo endpoint: `https://api.open-meteo.com/v1/forecast`
- Query parameters: `latitude`, `longitude`, `hourly=temperature_2m,precipitation_probability,weather_code,wind_speed_10m`, `timezone=auto`, `forecast_days=7`
- Response structure: map `hourly` arrays into normalized `list` entries and return first 9

**Error Handling:**
- Rescue `Faraday::TimeoutError` → return error_result("Timeout: {message}")
- Rescue `JSON::ParserError` → return error_result("Invalid JSON response")
- HTTP 4xx/5xx responses → check response.success?; if false, return error_result("HTTP {status}: {message}")
- Generic StandardError → return error_result("Unexpected: {message}")

**Result Format:**
```ruby
# Success:
{ success: true, data: {list: [...], timezone: "UTC", ...}, error: nil }

# Failure:
{ success: false, data: nil, error: "HTTP 401: Invalid API key" }
```

**Private Methods:**
- `http_client` — builds Faraday connection (memoized)
- `parse_response(response)` — extracts forecast data from API response
- `value_at` — helper to safely read values from `hourly` arrays by index
- `success_result(data)` — constructs success hash
- `error_result(message)` — constructs error hash

Optional: Create `app/services/provider_error.rb` as a custom exception for provider-specific errors (used in logging/monitoring later).

**Verify:**
```bash
bundle exec rspec spec/services/weather_provider_spec.rb
```

**Done:** WeatherProvider fetches weather; returns success/error hashes; never raises exceptions to caller.

---

### Task 1.2: Write WeatherProvider Specs

**Files:** `spec/services/weather_provider_spec.rb`

**Action:** Write comprehensive specs covering:

**Happy Path:**
- `WeatherProvider.fetch(event)` with valid event returns `{success: true, data: {list: [...]}}` (use stubbed HTTP)
- Data includes first 9 forecast entries
- Open-Meteo query params are passed with latitude/longitude and hourly fields

**Error Cases:**
- Missing coordinates (nil latitude/longitude) → error_result("Missing coordinates") (no HTTP call made)
- HTTP timeout (5s exceeded) → rescues Faraday::TimeoutError → error_result("Timeout: ...")
- HTTP 401 (invalid API key) → error_result("HTTP 401: ...")
- HTTP 500 (API server error) → error_result("HTTP 500: ...")
- Malformed JSON response → error_result("Invalid JSON response")
- Network error (Faraday::ConnectionFailed) → error_result("Connection error: ...")

**Retry Behavior:**
- First call fails; second call succeeds → result reflects success (not error)
- Verify Faraday retry middleware is configured (use spy on HTTP calls to confirm)

**HTTP Configuration:**
- Timeout is exactly 5 seconds (not longer, not missing)
- Max retries = 2 (from faraday-retry config)
- JSON response parsing enabled

Each test should:
- Use `stub_weather_success` / `stub_weather_failure` helpers from Wave 0 Task 0.3
- Verify the result hash structure
- NOT make real HTTP calls (all stubbed)

**Done:** All WeatherProvider specs pass; HTTP client behavior fully documented and tested.

---

## Wave 2: Background Jobs & Scheduler

**Purpose:** Implement the job layer (FetchWeatherJob, ScheduleWeatherFetchesJob) and configure Solid Queue for recurring task execution.

**Duration estimate:** 5–6 hours

**Dependencies:** Wave 0 & 1 complete (EventContext model + WeatherProvider service ready)

**Success criteria (automated):**
- `bundle exec rspec spec/jobs/fetch_weather_job_spec.rb` — Job tests pass
- `bundle exec rspec spec/jobs/schedule_weather_fetches_job_spec.rb` — Scheduler tests pass
- `bundle exec rspec spec/support/solid_queue_helper_spec.rb` — Solid Queue config works
- `bundle exec rspec --fail-fast` — Full suite passes (pre-commit gate)

---

### Task 2.1: Configure Solid Queue & Active Job

**Files:** `config/recurring.yml`, `config/environments/development.rb`, `config/environments/test.rb`, `db/migrate/[timestamp]_install_solid_queue.rb`

**Action:**

**Step 1: Install Solid Queue migrations**
- Run `bundle exec rails solid_queue:install` (generates migration for `solid_queue_*` tables)
- Migrations create: `jobs`, `scheduled_executions`, `processes`, `claimed_executions` tables
- Review migration (should be standard Solid Queue setup)
- Run `bundle exec rails db:migrate` to create tables in dev/test

**Step 2: Configure Active Job backend**
- Update `config/application.rb` to set: `config.active_job.queue_adapter = :solid_queue`
- This tells Rails that all `ActiveJob` jobs should use Solid Queue as the backend

**Step 3: Create recurring task config**
- Create `config/recurring.yml` (Solid Queue config for recurring tasks)
- Add entry for `ScheduleWeatherFetchesJob`:
  ```yaml
  production:
    schedule_weather_fetches:
      class: ScheduleWeatherFetchesJob
      schedule: every 1 hour
      queue: background
      description: "Discover and enqueue weather fetches for events 24h away"
      tags: ["recurring", "provider", "weather"]
  
  development:
    schedule_weather_fetches:
      class: ScheduleWeatherFetchesJob
      schedule: every 5 minutes  # Faster in dev for testing
      queue: background
  
  test:
    # Recurring tasks disabled in test (use inline job execution)
  ```

**Step 4: Environment configuration**
- `config/environments/development.rb`: Add `config.solid_queue.mode = :async` (jobs run in background threads)
- `config/environments/test.rb`: Add `config.active_job.queue_adapter = :test` (jobs enqueued in test array; inline execution for verification)
- `config/environments/production.rb`: (unchanged; supervisor manages job execution)

**Step 5: Verify Solid Queue schema**
- Run `bundle exec rails db:migrate` in all environments (dev/test)
- Verify `SolidQueue::Job` table exists and is accessible

**Verify:**
```bash
bundle exec rails db:migrate
bundle exec rails db:migrate RAILS_ENV=test
# Inspect schema
bundle exec rails dbconsole -e test
# \d solid_queue_jobs  (PostgreSQL)
```

**Done:** Solid Queue tables created; Active Job configured to use :solid_queue; recurring.yml ready.

---

### Task 2.2: Implement FetchWeatherJob

**Files:** `app/jobs/fetch_weather_job.rb`, `app/jobs/application_job.rb` (base class updates)

**Action:**

Create `FetchWeatherJob < ApplicationJob` that:

**Job Configuration:**
- `queue_as :default` — standard queue (not urgent)
- `retry_on StandardError, wait: :exponentially_longer, attempts: 3` — retry up to 3 times with backoff (5s, 25s, 125s)
- `discard_on ActiveJob::DeserializationError` — silently discard if event no longer exists

**Perform Method:**
```ruby
def perform(event_id)
  event = Event.find(event_id)
  result = WeatherProvider.fetch(event)
  
  if result[:success]
    # Store weather data
    event.ensure_context
    event.event_context.update!(
      weather_data: result[:data],
      weather_status: "success",
      weather_fetched_at: Time.current,
      expires_at: 24.hours.from_now
    )
  else
    # Log failure; don't raise (graceful degradation)
    log_provider_error(event, result[:error])
    event.ensure_context
    event.event_context.update!(
      weather_status: "failed",
      weather_error: result[:error],
      weather_fetched_at: Time.current
    )
  end
rescue ActiveRecord::RecordNotFound
  # Event deleted after job was enqueued; silently discard
  Rails.logger.info("Event #{event_id} deleted before weather fetch")
end

private

def log_provider_error(event, error_msg)
  Rails.logger.warn(
    "Weather provider error for event #{event.id}: #{error_msg}",
    tags: ["provider", "weather", "external_api"]
  )
end
```

**Error Handling:**
- Provider errors (network, timeout, API errors) caught in WeatherProvider; job receives `:success => false`
- Job does NOT raise; it logs and updates EventContext.weather_status to "failed"
- Job retries only if unexpected exceptions occur (not expected provider failures)
- ActiveRecord::RecordNotFound handled gracefully (event was deleted)

**Update ApplicationJob** (if not already present):
- Add `retry_on StandardError, wait: :exponentially_longer, attempts: 3` as default
- Add error handler: `rescue_from StandardError do |exception|` → log with context, then re-raise for retry

**Verify:**
```bash
bundle exec rails generate job fetch_weather
# Review generated skeleton; implement perform method as above
```

**Done:** FetchWeatherJob exists; performs weather fetch; logs errors; updates EventContext without raising.

---

### Task 2.3: Implement ScheduleWeatherFetchesJob (Recurring Scheduler)

**Files:** `app/jobs/schedule_weather_fetches_job.rb`

**Action:**

Create `ScheduleWeatherFetchesJob < ApplicationJob` that discovers events 24–24.5 hours away and enqueues individual FetchWeatherJob instances.

**Job Configuration:**
- `queue_as :background` — lower priority queue
- No retry policy (it's a discovery task; if it fails, next hourly run will catch events)

**Perform Method:**
```ruby
def perform
  target_start = 24.hours.from_now
  target_end = 24.5.hours.from_now
  
  # Find events starting in the 24–24.5 hour window
  events = Event.where(starts_at: target_start..target_end).find_each do |event|
    # Skip if weather already fetched (optimization)
    next if event.event_context&.weather_fetched_at.present?
    
    # Enqueue individual fetch job for this event
    FetchWeatherJob.perform_later(event.id)
    
    Rails.logger.info("Enqueued weather fetch for event #{event.id}")
  end
  
  Rails.logger.info("Scheduled weather fetches completed. Events queued: #{events.count}")
end
```

**Logic Explanation:**
- Queries for events with `starts_at` between now+24h and now+24.5h
- The 24–24.5h window (0.5 hour = 30 minutes) ensures all events are caught even if queries are staggered
- Recurring job runs every 1 hour (configurable in recurring.yml)
- Skips events that already have weather (optimization; optional)
- Enqueues FetchWeatherJob for each event (does NOT wait for jobs to complete)

**Edge Cases:**
- New events created after scheduling → next hourly run will pick them up
- Event cancelled/deleted → FetchWeatherJob handles gracefully (ActiveRecord::RecordNotFound)
- High event volume (100+ events in 24–24.5h window) → jobs enqueued; Solid Queue processes concurrently

**Verify:**
```bash
bundle exec rails generate job schedule_weather_fetches
# Implement perform method as above
```

**Done:** ScheduleWeatherFetchesJob enqueues FetchWeatherJob for events 24h away; runs hourly (configured in recurring.yml).

---

### Task 2.4: Write Fetch & Scheduler Job Specs

**Files:** `spec/jobs/fetch_weather_job_spec.rb`, `spec/jobs/schedule_weather_fetches_job_spec.rb`

**Action:**

**FetchWeatherJob Specs:**

- **Happy path:** Job fetches weather, stores in EventContext with status="success", expires_at set to 24h from now
- **Provider failure:** Job receives error result, updates EventContext with status="failed" and error message; job completes (doesn't raise)
- **Event deleted:** Job rescues RecordNotFound, logs, completes gracefully
- **Retry behavior:** Job with temporary exception (e.g., database connection error) is retried; after 3 attempts it's discarded (or dead-lettered)
- **Timeout scenario:** WeatherProvider returns timeout error; FetchWeatherJob captures it, logs, completes

Use `ActiveJob::Base.queue_adapter = :test` in test environment to capture enqueued jobs.

**ScheduleWeatherFetchesJob Specs:**

- **Discovery:** Job finds events with starts_at between now+24h and now+24.5h
- **Job enqueue:** For each discovered event, FetchWeatherJob is enqueued (verify via `ActiveJob::Base.queue_adapter.enqueued_jobs`)
- **Edge case — no events:** Job completes without error if no events match window
- **Edge case — high volume:** Job enqueues 50+ jobs without errors
- **Edge case — already fetched:** Job skips events that already have weather_fetched_at set (optimization test)

Each spec should:
- Use factory to create test events with starts_at in correct window
- Stub WeatherProvider (or mock it)
- Verify job performs without raising
- Verify database state changes (EventContext updates, job logging)
- Use clear assertion names (e.g., `expect(event.event_context.weather_status).to eq("success")`)

**Done:** All FetchWeatherJob and ScheduleWeatherFetchesJob specs pass; job behavior fully tested.

---

### Task 2.5: Verify Solid Queue Integration & Job Execution

**Files:** None (integration verification)

**Action:**

Test that Solid Queue is properly configured and jobs can be executed:

**Dev Environment:**
- Start Rails server: `bin/dev`
- In another terminal, verify Solid Queue job supervisor is running: `ps aux | grep solid_queue`
- Submit a manual job: 
  ```ruby
  FetchWeatherJob.perform_later(Event.first.id)  # In rails console
  ```
- Watch job supervisor logs; verify job is picked up, executed, and completed

**Test Environment:**
- Run test suite: `bundle exec rspec --fail-fast`
- All tests should pass; Active Job should use `:test` adapter
- Jobs enqueued in specs should be verifiable via `ActiveJob::Base.queue_adapter.enqueued_jobs`

**Pre-commit Verification:**
- Run `.githooks/pre-commit` hook manually: `bash .githooks/pre-commit`
- Should run `bundle exec rspec --fail-fast` and pass (or fail with clear error message)

**Verify:**
```bash
bundle exec rspec spec/jobs/ --fail-fast
bundle exec rspec --fail-fast  # Full suite
```

**Done:** Solid Queue configured; jobs execute successfully in dev/test; pre-commit gate satisfied.

---

## Wave 3: Integration Testing & API Response

**Purpose:** Verify the complete flow (scheduler → job → service → database → API response) works end-to-end; ensure weather data is returned via API.

**Duration estimate:** 3–4 hours

**Dependencies:** Wave 0, 1, 2 complete

**Success criteria (automated):**
- `bundle exec rspec spec/requests/events_spec.rb` — API request tests pass
- `bundle exec rspec spec/integration/weather_flow_spec.rb` — End-to-end flow tests pass
- Full RSpec suite passes
- Manual verification: `GET /api/v1/events/:id` returns weather data from EventContext

---

### Task 3.1: Update Event Entity to Include Weather

**Files:** `app/api/v1/entities/event_entity.rb` (or similar; verify existing structure), `app/api/entities/event_context_entity.rb` (new)

**Action:**

**EventContextEntity (new):**
Create a Grape entity that represents EventContext for API responses:
```ruby
module Api
  module Entities
    class EventContextEntity < Grape::Entity
      expose :weather, if: -> (ctx, _) { ctx.weather_available? } do |ctx|
        {
          forecast: ctx.weather_data,
          fetched_at: ctx.weather_fetched_at,
          expires_at: ctx.expires_at
        }
      end
      
      expose :weather_status, if: -> (ctx, _) { ctx.weather_status == "failed" } do |ctx|
        "Weather currently unavailable (#{ctx.weather_error})"  # Show reason in dev
      end
    end
  end
end
```

Note: `weather_status` is only exposed if failed (for debugging in dev); success/pending are silent (omit weather from response).

**EventEntity (update):**
Update existing EventEntity to include weather when available:
```ruby
module Api
  module Entities
    class EventEntity < Grape::Entity
      expose :id, :name, :starts_at, :venue, :latitude, :longitude
      
      expose :weather, using: EventContextEntity, if: -> (event, _) { event.event_context.present? }
    end
  end
end
```

The `using: EventContextEntity` tells Grape to render nested entity. If event_context doesn't exist or weather is not available, omit the weather field entirely (graceful degradation).

**Verify:**
```bash
# Inspect existing EventEntity structure (may vary from this template)
cat app/api/v1/entities/event_entity.rb
# Update to include weather using EventContextEntity
```

**Done:** EventEntity includes weather data from EventContext; API response includes forecast when available.

---

### Task 3.2: Write Event Request Specs (API Testing)

**Files:** `spec/requests/events_spec.rb` (update existing or create), `spec/requests/v1/events_spec.rb`

**Action:**

Write specs for `GET /api/v1/events/:id` that verify:

**Happy path (weather available):**
- Create event + EventContext with weather data
- GET /api/v1/events/:id returns 200 OK
- Response includes weather object with forecast, fetched_at, expires_at
- Forecast data matches EventContext.weather_data

**Graceful degradation (weather failed):**
- Create event + EventContext with weather_status="failed"
- GET /api/v1/events/:id returns 200 OK (event is not affected by weather failure)
- Response does NOT include weather field (or weather_status is hidden in response)
- Event details (name, starts_at, venue) are still present

**Graceful degradation (no context):**
- Create event with NO EventContext
- GET /api/v1/events/:id returns 200 OK
- Response does NOT include weather field
- Event details are present

**Fresh vs stale weather:**
- EventContext with expires_at in future → weather_fresh? returns true
- EventContext with expires_at in past → weather_fresh? returns false (optional: can trigger refetch in Phase 2)

Specs should:
- Use factory to create events/contexts
- Make actual HTTP requests to API (not stub)
- Verify JSON response structure (use expect on response.parsed_body)
- Check response status and presence/absence of weather field

**Done:** Event API returns weather from EventContext when available; gracefully omits weather on failure.

---

### Task 3.3: Write End-to-End Integration Specs

**Files:** `spec/integration/weather_flow_spec.rb` (new)

**Action:**

Write comprehensive end-to-end specs that verify the complete flow:

**Scenario 1: Scheduler enqueues job; job fetches weather; API returns data**
1. Create event with starts_at = now + 24h
2. Manually trigger ScheduleWeatherFetchesJob (or invoke via `ActiveJob::Base.queue_adapter.perform_enqueued_jobs`)
3. Verify FetchWeatherJob was enqueued
4. Manually trigger FetchWeatherJob.perform_now (or activate job queue)
5. Verify EventContext was created with weather_data
6. Call GET /api/v1/events/:id
7. Assert response includes weather forecast

**Scenario 2: Weather API fails; job handles gracefully**
1. Create event with starts_at = now + 24h
2. Stub WeatherProvider to return error
3. Enqueue & execute FetchWeatherJob
4. Verify EventContext.weather_status = "failed"
5. Verify Rails.logger contains error message
6. Call GET /api/v1/events/:id
7. Assert response is 200 OK; weather field omitted

**Scenario 3: Scheduler skips events outside 24–24.5h window**
1. Create events with starts_at = now + 20h, now + 24.1h (within window), now + 28h
2. Execute ScheduleWeatherFetchesJob
3. Verify only the now+24.1h event was enqueued
4. Verify 20h and 28h events were not enqueued

**Scenario 4: Job retry on transient failure**
1. Stub WeatherProvider to fail first time, succeed second time
2. Enqueue FetchWeatherJob
3. Simulate transient error (Faraday::TimeoutError)
4. Verify job is retried
5. Verify EventContext is created with success after retry

Each scenario should:
- Setup test data (events, stubs)
- Execute the flow (enqueue, execute jobs, call API)
- Verify outcomes (database state, API response, logs)
- Be isolated (no dependencies between scenarios)

**Done:** End-to-end flow tested; scheduler → job → service → database → API verified.

---

### Task 3.4: Verify Full RSpec Suite & Pre-Commit Gate

**Files:** None (verification only)

**Action:**

Run full test suite to ensure all specs pass and pre-commit hook is satisfied:

```bash
# Full RSpec suite (should pass)
bundle exec rspec --fail-fast

# Pre-commit hook simulation
bash .githooks/pre-commit

# Verify no failing tests
echo $?  # Should be 0 (success)
```

If any failures occur:
- Review error message
- Fix failing spec or code
- Re-run until all pass

Once all pass:
- Verify coverage is reasonable (use `COVERAGE=true bundle exec rspec` or similar)
- Commit changes: `git add . && git commit -m "feat(phase-1): complete provider foundation"`

**Verify:**
```bash
bundle exec rspec --fail-fast
# All tests should be green
```

**Done:** All RSpec tests pass; pre-commit gate satisfied; Phase 1 complete.

---

## Task Sequencing & Wave Dependencies

```
┌─────────────────────────────────────────────────────────────────────┐
│  Wave 0: Infrastructure & Models (must complete first)             │
│  ├── 0.1: Add Faraday gem                                          │
│  ├── 0.2: Create EventContext model & migration                    │
│  ├── 0.3: Create EventContext factory & test support              │
│  └── 0.4: Write EventContext model specs                           │
│                        ↓                                            │
│  Wave 1: Service Layer (depends on Wave 0)                         │
│  ├── 1.1: Implement WeatherProvider service                        │
│  └── 1.2: Write WeatherProvider specs                              │
│                        ↓                                            │
│  Wave 2: Background Jobs & Scheduler (depends on Waves 0 & 1)      │
│  ├── 2.1: Configure Solid Queue & Active Job                       │
│  ├── 2.2: Implement FetchWeatherJob                                │
│  ├── 2.3: Implement ScheduleWeatherFetchesJob                      │
│  ├── 2.4: Write job specs                                          │
│  └── 2.5: Verify Solid Queue integration                           │
│                 ↓                    ↓                              │
│              (overlap okay)      (overlap okay)                     │
│                 ↓                    ↓                              │
│  Wave 3: Integration Testing (depends on Waves 0, 1, 2)            │
│  ├── 3.1: Update Event entity to include weather                   │
│  ├── 3.2: Write Event request specs                                │
│  ├── 3.3: Write end-to-end integration specs                       │
│  └── 3.4: Verify full suite & pre-commit gate                      │
└─────────────────────────────────────────────────────────────────────┘

Parallelization:
- Wave 0 tasks must be sequential (later tasks depend on earlier ones)
- Wave 1 tasks can start once Wave 0 is complete
- Wave 2 tasks must complete Wave 2.1 before 2.2–2.5
- Wave 3 can start once Waves 0, 1, 2 are complete (overlaps okay)
- Actual execution: Wave 0 → Wave 1 → Wave 2 (2.1 then 2.2–2.5 parallel) → Wave 3

Critical path: All waves sequential (no true parallelism due to dependencies)
Estimated total: 15–22 hours focused development
```

---

## Verification Strategy

### Per-Wave Validation

**After Wave 0:**
```bash
bundle exec rspec spec/models/event_context_spec.rb
bundle exec rspec spec/factories/
bundle exec rails db:migrate && echo "✓ Migrations clean"
```
Expected: All tests green; EventContext model ready; Faraday gem installed.

**After Wave 1:**
```bash
bundle exec rspec spec/services/weather_provider_spec.rb
```
Expected: WeatherProvider fetches weather; returns hashes; HTTP client configured.

**After Wave 2:**
```bash
bundle exec rspec spec/jobs/
bundle exec rspec --fail-fast
```
Expected: FetchWeatherJob and ScheduleWeatherFetchesJob tests pass; Solid Queue integrated.

**After Wave 3:**
```bash
bundle exec rspec spec/requests/
bundle exec rspec spec/integration/weather_flow_spec.rb
bundle exec rspec --fail-fast
bash .githooks/pre-commit
```
Expected: All specs pass; API returns weather; pre-commit gate satisfied.

### End-of-Phase Validation (UAT)

Run this checklist before marking Phase 1 complete:

- [ ] `bundle exec rspec --fail-fast` — All tests green
- [ ] `bash .githooks/pre-commit` — Pre-commit hook passes
- [ ] `bundle list | grep faraday` — Faraday gem installed
- [ ] `bundle exec rails db:migrate` — EventContext migration runs clean in dev/test
- [ ] Manual test: 
  ```ruby
  event = Event.first
  result = WeatherProvider.fetch(event)
  puts result  # Should show {success: true, data: {...}} or {success: false, error: "..."}
  ```
- [ ] Manual test:
  ```ruby
  # Simulate ScheduleWeatherFetchesJob
  ScheduleWeatherFetchesJob.perform_now
  # Check Solid Queue job table for enqueued FetchWeatherJob
  SolidQueue::Job.where(class_name: 'FetchWeatherJob').count  # Should be > 0
  ```
- [ ] Manual test:
  ```ruby
  # Check API response
  event = Event.where.not(latitude: nil).first
  event.create_event_context!(weather_data: {list: [...]}, weather_status: "success")
  # GET /api/v1/events/{id} should include weather in response
  ```

---

## Known Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| **Weather API rate limit exceeded** | Medium | 24h weather fetches start failing | Monitor Open-Meteo usage and fair-use limits; switch to commercial plan if traffic grows. |
| **Job hangs on timeout (no explicit timeout set)** | High | Job never completes; clogs queue | **CRITICAL:** Always set Faraday timeout to 5s; use `faraday-retry` to prevent infinite loops. |
| **EventContext records bloat over time** | Low (Phase 1) | Disk space, query slowdown | Phase 2 can add cleanup job (e.g., delete contexts older than 7 days). Not urgent. |
| **Race condition: two jobs fetch weather for same event** | Low | Duplicate EventContext or update clash | Use `create_or_update_context` or ensure unique index on `event_id`. Solid Queue handles deduplication at job level. |
| **Event deleted; FetchWeatherJob tries to fetch** | Low | Job crashes on RecordNotFound | Rescue `ActiveRecord::RecordNotFound` in FetchWeatherJob; log and discard gracefully. |
| **Solid Queue supervisor crashes; jobs stuck** | Very Low | Queued jobs never execute until restart | Supervisor managed by `bin/dev` (or Docker/systemd in production). Solid Queue is well-tested; crashes rare. Monitor supervisor health. |
| **JSON parsing fails on malformed API response** | Low | Job crashes; needs retry | Rescue `JSON::ParserError` in WeatherProvider; return error_result; job doesn't raise. |
| **EventContext expires_at is null; API leaks stale weather** | Low | Users see week-old forecast | Set `expires_at` to 24.hours.from_now when fetching; check `weather_fresh?` before exposing (Phase 2). |
| **Provider request details leaked in logs** | Medium | Sensitive request metadata exposure | **NEVER log full response body in Faraday.** Keep logs minimal and structured. |
| **Pre-commit hook not installed** | Low | Tests not enforced; broken code merged | Verify `.githooks/pre-commit` is executable; setup instructions in README. Remind developer on first commit. |

---

## Success Criteria

**Phase 1 is complete when:**

✅ All RSpec tests pass (`bundle exec rspec --fail-fast`)

✅ Pre-commit hook passes (`.githooks/pre-commit`)

✅ EventContext model exists with correct associations and scopes

✅ WeatherProvider.fetch returns result hashes (success or error) without raising

✅ FetchWeatherJob persists weather data to EventContext

✅ ScheduleWeatherFetchesJob enqueues FetchWeatherJob for events 24h away

✅ Solid Queue configured and jobs execute in dev/test environments

✅ GET /api/v1/events/:id returns weather data from EventContext when available

✅ Failed weather fetches are logged but don't affect event API response (graceful degradation)

✅ All requirements met:
  - EXT-01: ✅ Weather fetches 24h before event
  - EXT-02: ✅ Fetched weather stored with event (via EventContext)
  - EXT-06: ✅ Failed external lookups don't block browsing/booking
  - INT-01: ✅ Weather providers isolated behind service objects
  - INT-02: ✅ Weather fetches run through background jobs
  - INT-03: ✅ External API failures recorded/logged

---

## Next Steps

After Phase 1 completion:

1. **Phase 2: Parking Integration**
   - Extends EventContext with parking_info and parking_status fields
   - Implements ParkingProvider service (follows WeatherProvider pattern)
   - Adds parking lookup job (fetch-on-demand)
   - Extends EventEntity to include parking data

2. **Phase 3: API Endpoints for External Data**
   - Adds EventContextPolicy (authorization)
   - Exposes separate GET /api/v1/events/:id/context endpoint
   - Adds EventContextEntity with version/staleness indicators
   - Implements caching headers for external data

3. **Phase 4: Monitoring & Error Tracking**
   - Integrate Sentry for error reporting
   - Add alerting for repeated provider failures
   - Dashboard for provider health metrics

---

## Appendix: File Structure After Phase 1

```
app/
├── jobs/
│   ├── application_job.rb          ← Updated with retry defaults
│   ├── fetch_weather_job.rb        ← NEW
│   └── schedule_weather_fetches_job.rb ← NEW
├── services/
│   ├── weather_provider.rb         ← NEW
│   └── provider_error.rb           ← NEW (optional)
├── models/
│   ├── event.rb                    ← Updated: has_one :event_context
│   └── event_context.rb            ← NEW
├── api/
│   ├── v1/
│   │   └── entities/
│   │       └── event_entity.rb     ← Updated: includes weather
│   └── entities/
│       └── event_context_entity.rb ← NEW
└── policies/
    └── application_policy.rb       ← Unchanged for Phase 1

config/
├── recurring.yml                   ← NEW (Solid Queue recurring tasks)
├── application.rb                  ← Updated: active_job adapter
├── environments/
│   ├── development.rb              ← Updated: solid_queue mode
│   └── test.rb                     ← Updated: active_job adapter
└── initializers/
    └── (unchanged)

db/
├── migrate/
│   ├── [timestamp]_install_solid_queue.rb  ← NEW (Solid Queue tables)
│   └── [timestamp]_create_event_contexts.rb ← NEW (EventContext table)
└── schema.rb                       ← Updated: reflects new tables

spec/
├── factories/
│   └── event_context_factory.rb    ← NEW
├── models/
│   └── event_context_spec.rb       ← NEW
├── services/
│   └── weather_provider_spec.rb    ← NEW
├── jobs/
│   ├── fetch_weather_job_spec.rb   ← NEW
│   └── schedule_weather_fetches_job_spec.rb ← NEW
├── requests/
│   └── events_spec.rb              ← Updated: include weather tests
├── integration/
│   └── weather_flow_spec.rb        ← NEW
├── support/
│   └── weather_api_stubs.rb        ← NEW
└── fixtures/
    └── weather_api_response.json   ← NEW (sample API response)
```

---

**Plan prepared by:** GSD Planner  
**Date:** May 14, 2026  
**Status:** Ready for execution
