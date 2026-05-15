# Phase 2 Verification — Weather Context API

Purpose
-------
Define concrete checks that prove acceptance criteria for Phase 2.

Acceptance checks
- API contract
  - [ ] Event detail response includes `weather` (or equivalent fields) with `weather_status`, `weather_fetched_at`, and `weather_error_code`.
  - [ ] Response does not contain raw provider error messages or stack traces.

- Freshness & semantics
  - [ ] `weather_status == "current"` when `weather_fetched_at` within 24h of now (unit test for predicate).
  - [ ] `missing` when no `EventContext` or `weather_data` present.
  - [ ] `failed` when job recorded a failure and `weather_error_code` set.

- Jobs & model
  - [ ] `FetchWeatherJob` sets `expires_at` to 24 hours and writes `weather_status`/`weather_error_code` per mapping.
  - [ ] Integration test simulating job run produces expected `weather_status` variants.

- Tests (must pass before merge)
  - [ ] Unit tests: mapping utility covers expected provider error inputs → canonical `weather_error_code` outputs.
  - [ ] Model/predicate tests for `weather_fresh?` and derived `weather_status`.
  - [ ] Request specs for event detail endpoint for `current` / `missing` / `failed`.

- Docs & migration
  - [ ] Entity contract documented in PR and `.planning` changelog updated.
  - [ ] If migration added, migration rollback tested in dev environment.

How to run verification locally (developer notes)
1. Run unit tests: `bundle exec rspec spec/models spec/services` (or targeted tests).
2. Run request specs: `bundle exec rspec spec/requests/api/v1/events_spec.rb`.
3. Run the fetch job manually in the console and verify database state:

```bash
rails c
Event.find(...).ensure_context
FetchWeatherJob.perform_now(event_context_id)
```

Exit criteria
- All checks above pass and CI shows no regressions. Merge and close phase.
