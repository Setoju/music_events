# Phase 2: Weather Context API - Context

**Gathered:** 2026-05-15
**Status:** Ready for planning

## Phase Boundary

Expose weather context in event detail responses so clients can see whether
weather data is current, missing, or failed. This phase implements the API
surface and the data visibility rules only — provider integration and prefetch
mechanism were established in Phase 1 and are assumed available.

## Implementation Decisions

### Freshness semantics
- **D-01:** `current` is defined as weather data fetched within the last **24 hours**.
  - Rationale: Matches the requirement to prefetch at 24 hours before event start
    and keeps client semantics simple. Downstream agents should use
    `weather_fetched_at` / `expires_at` to derive recency.

### Failure handling & visibility
- **D-02:** API will expose a `weather_status` field with enumerated values
  `current` / `missing` / `failed`, a `weather_fetched_at` timestamp, and a
  short `weather_error_code` for failed fetches. Provider internals and raw
  error messages are NOT exposed to clients.
  - Rationale: Clients need actionable state without coupling to provider
    internals. `error_code` allows instruments and UIs to show different
    friendly messages (retrying, temporary outage, rate-limited) without
    leaking logs.

### Agent discretion
- The implementation may choose concise, stable `error_code` values
  (e.g., `provider_timeout`, `rate_limited`, `no_data`) and map provider
  errors to those codes in the service layer. Downstream planner may design
  the mapping.

## Canonical References

### Requirements & Roadmap
- .planning/REQUIREMENTS.md — EXT-03: API returns weather context for an event
- .planning/ROADMAP.md — Phase 2: Weather Context API (scope anchor)
- .planning/PROJECT.md — Project-level constraints and previously agreed
  decisions (service layer; scheduled prefetch)

### Code & integration points
- app/models/event.rb — `has_one :event_context`; `ensure_context` helper
- app/models/event_context.rb — current `weather_status`, `weather_data`,
  `weather_fetched_at`, `expires_at` fields and helper predicates (`weather_fresh?`)
- app/jobs/fetch_weather_job.rb — fetch job that writes `weather_status`,
  `weather_data`, `weather_error` and sets `expires_at` (currently 24h)
- app/jobs/schedule_weather_fetches_job.rb — schedules fetches ~24 hours before start
- app/services/weather_provider.rb — provider abstraction (fetch interface)
- app/api/v1/events.rb and app/api/entities/* — update event response to include
  `weather` context (entity changes required)

## Existing Code Insights

### Reusable Assets
- `Event#ensure_context` and `EventContext` model already exist; reuse them
  rather than adding weather columns directly to `events`.
- `FetchWeatherJob` and `ScheduleWeatherFetchesJob` implement prefetch and
  provider isolation patterns; downstream work should extend or reuse these
  jobs/services.

### Established Patterns
- Provider integrations live in `app/services/*_provider.rb` and return a
  `{ success: bool, data: <payload>, error: <string> }` shape consumed by jobs.
- Background work uses `ApplicationJob` with `perform_later` and retry_on
  policies; follow the same pattern for additional retries or backoff.

### Integration Points
- Update Grape entities for `Event` to include a `weather` object or fields.
- Event detail endpoints (`app/api/v1/events.rb`) are the integration surface.
- Use `EventContext` predicates (`weather_fresh?`, `weather_available?`) to
  determine `weather_status` when serializing responses.

## Specific Ideas
- Keep `expires_at` semantics (job currently sets it to 24 hours). Planner
  may add a refresh path if nearer-to-event updates are later required.
- Map provider errors to stable `weather_error_code` values in
  `app/services/weather_provider.rb` or a mapping utility.

## Deferred Ideas
- Consider an on-demand refresh endpoint for clients to request a fresh
  weather fetch if they need more current data (defer to later phase).

---

*Phase: 02-Weather Context API*
*Context gathered: 2026-05-15*
