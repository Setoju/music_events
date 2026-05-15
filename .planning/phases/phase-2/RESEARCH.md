# Phase 2 — Research (Weather Context API)

Phase: 02 — Weather Context API
Collected: 2026-05-15

Summary
-------
This research note summarizes the evidence and open questions used to drive planning for Phase 2. Phase 1 established provider prefetch and the `EventContext` model; Phase 2 implements the API surface and visibility semantics (`weather_status`, `weather_fetched_at`, `weather_error_code`).

Key findings from 02-CONTEXT.md
- `current` = fetched within last 24 hours; use `weather_fetched_at` / `expires_at` to derive recency.
- Expose `weather_status` enum: `current` / `missing` / `failed` and a short stable `weather_error_code` (no provider internals).
- Existing assets: `Event#ensure_context`, `EventContext` model, `FetchWeatherJob`, `ScheduleWeatherFetchesJob`, and `weather_provider` service abstraction.

Open questions (research tasks)
1. Confirm canonical `weather_error_code` values and mapping table (e.g., `provider_timeout`, `rate_limited`, `no_data`).
2. Confirm whether `Event` entities should expose a `weather` object or flattened fields. (Entity change scope impacts front-end contracts and clients.)
3. Determine required changes to existing jobs: are retry/backoff policies sufficient or do we need additional logging/metrics for `failed` states?
4. Confirm privacy/security constraints — ensure no raw provider errors or stack traces are surfaced.

References
- .planning/REQUIREMENTS.md — EXT-03
- .planning/ROADMAP.md — Phase 2 anchor
- app/models/event_context.rb, app/jobs/fetch_weather_job.rb, app/services/weather_provider.rb

Next research actions (recommended, small tasks)
- Create `config/weather_error_mapping.yml` (or code-level mapping) with canonical error codes and unit tests.
- Draft the entity contract for the API response and circulate for review (`app/api/entities/event_entity.rb`).
- Add a small integration test scaffold that asserts `weather_status` variants in event detail responses.

Outcome
- With these research tasks completed the planner can produce a narrow, verifiable implementation plan mapping to entities, model updates (if any), job behavior, and tests.
