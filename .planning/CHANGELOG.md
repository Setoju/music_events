## Phase 2 — Weather Context API (2026-05-15)

- Add `weather` object to event context serialization with fields:
  - `weather_status` — one of `current` / `missing` / `failed`
  - `weather_fetched_at` — ISO8601 timestamp or null
  - `weather_error_code` — short stable code when `failed`, otherwise null
- Introduce `WeatherErrorMapper` and `config/weather_error_mapping.yml` for canonical error codes
- Add unit tests for `WeatherErrorMapper`
