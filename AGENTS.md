# Music Events API - Agent Architecture

## Core Architecture

**Stack**: Rails 8 API + Grape (versioned endpoints) + JWT auth + Pundit policies

**Domains**: Events, Artists, Bookings, Reviews, Users with role-based access control

## Code Standards

- **API Design**: RESTful with Grape v1 versioning (`/api/v1/*`); entities define response contracts
- **Auth**: JWT tokens via `JwtToken` service; token revocation via `RevokedJwtToken` model
- **Authorization**: Pundit policies in `app/policies/` for all resource actions
- **Tests**: Factory-based specs in `spec/` with Rails helpers and faker library; test all policy boundaries

## Decision Frameworks

1. **New Endpoints**: Add to versioned Grape routes (`app/api/v1/`), define entity in `app/api/entities/`, add policy in `app/policies/`
2. **Data Changes**: Use migrations with rollback safety; update factories and models to match
3. **Authorization**: Always enforce policies; query current_user role via policy context
4. **Errors**: Return consistent API errors from Grape endpoints (error codes/messages via entities)
5. **Testing**: Cover new features with tests, following code standarts listed above

## Enforcement Policies

**Pre-Commit RSpec Validation**: All commits are gated behind passing RSpec tests. Git uses `.githooks/pre-commit` (configured via `core.hooksPath=.githooks`) to run `bundle exec rspec --fail-fast`. Commits are blocked if tests fail.

## Key Constraints

- JWT tokens handled server-side (no refresh token rotation currently)
- Roles: user, artist, admin (enforce at policy level, not controller)
- No frontend code in this repo (React frontend separate at `/react/music_events`)
