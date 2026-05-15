# Phase 2 Plan — Weather Context API

Phase: 02 — Weather Context API
Goal: Expose stable, client-friendly weather context in event detail responses with clear visibility rules and test coverage.

Acceptance Criteria
- Event detail API includes a `weather` object (or fields) containing:
  - `weather_status`: one of `current` / `missing` / `failed`.
  - `weather_fetched_at`: ISO8601 timestamp or null.
  - `weather_error_code`: short stable code when `failed`, otherwise null.
- No provider stack traces or raw error messages are leaked in responses.
- Background jobs continue to prefetch; `expires_at` semantics remain 24 hours and are used to determine `current`.
- Tests: unit tests for mapping logic, entity serialization specs, and integration/request spec showing each `weather_status`.

Deliverables
- `app/api/entities/event_entity.rb` (or equivalent Grape entity) updated to include `weather` contract.
- Migration and/or model updates if additional fields required in `EventContext` (minimal change preferred).
- Mapping utility: `config/initializers/weather_error_mapping.rb` or `config/weather_error_mapping.yml` + tests.
- Request/integration specs covering `current`, `missing`, and `failed` cases.
- Small doc: `.planning/phases/phase-2/RESEARCH.md` (done) and changelog entry in `.planning/CHANGELOG.md`.

Tasks
1. Design entity contract: decide `weather` object vs flattened fields (owner: backend). [1d]
   - Review front-end consumers if available; prefer `weather: { status, fetched_at, error_code }` for extensibility.
2. Implement serialization: update Grape entity and add presenter helpers. [1d]
3. Implement error-code mapping: add mapping table and unit tests. [0.5d]
4. Add/adjust model fields if missing (small migration). [0.5d]
5. Add/adjust job behavior or logging if research recommends (tbd). [0.5d]
6. Add request specs (3 cases) + unit tests for mapping and predicates. [1d]
7. Review and merge; add verification artifacts. [0.5d]

Estimated total: ~5 days (can be decomposed across multiple PRs; many tasks are small).

Risks & Mitigations
- Risk: Clients rely on a different entity shape. Mitigation: choose a backward-compatible shape and document in changelog; consider feature-flagging if necessary.
- Risk: Mapping misses provider cases. Mitigation: implement mapping as a centralized config with tests and telemetry for unmapped errors.

Verification plan: see VERIFICATION.md
