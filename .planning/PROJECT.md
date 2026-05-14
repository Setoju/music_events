# Music Events API

## What This Is

Music Events API is a Rails 8 API for managing events, artists, bookings, and reviews with JWT authentication and Pundit authorization. The next step is to enrich event pages with external event-day context, starting with weather forecasts and nearby parking prices.

## Core Value

Help attendees make better event decisions by surfacing timely, location-aware information before they leave for an event.

## Requirements

### Validated

- ✓ Users can authenticate with JWT-backed sign-in and sign-up flows — existing API
- ✓ Users can browse, create, and manage events through versioned Grape endpoints — existing API
- ✓ Users can book events and leave reviews with policy enforcement — existing API
- ✓ Role-based authorization is enforced through Pundit policies — existing API

### Active

- [ ] Fetch and persist weather forecasts for events 24 hours before event start.
- [ ] Fetch nearby parking options with prices for an event location.
- [ ] Expose the external data in the API so clients can show event-day weather and parking context.

### Out of Scope

- Artist news and artist subscriptions — useful later, but not part of the current external-data integration.
- A dedicated notifications page and notification history model — this work is about data enrichment first.
- Similar-events recommendations — separate discovery problem with different data needs.

## Context

The codebase already has a versioned Grape API, JWT auth, Pundit policies, and core event/booking/review domain models. There are no existing background jobs or external API client abstractions yet, so this work will need a scheduling and service layer rather than route-level integration.

The current `TODO.md` points to two external-data needs: weather forecasts 24 hours before events and nearby parking data with prices. The weather feature is time-sensitive and likely belongs in a scheduled job; the parking feature is more likely a fetch-on-demand or cached lookup tied to event location.

## Constraints

- **Tech stack**: Stay within Rails 8, Grape, JWT, and Pundit — the repo is an API-only backend and already centers those patterns.
- **Integration**: External APIs must be isolated behind service objects — this keeps provider changes and failure handling out of routes.
- **Timing**: Weather delivery must happen 24 hours before event start — the schedule is part of the requirement, not an implementation detail.
- **Reliability**: External provider outages or rate limits must not break core event operations — these features are additive, not blocking.

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Add a service layer for weather and parking providers | Keeps external dependencies isolated and testable | — Pending |
| Use scheduled background work for weather prefetching | The requirement is time-based and should not depend on user traffic | — Pending |
| Keep parking lookup tied to event location data | Nearby parking depends on the event's venue/geography | — Pending |

---
*Last updated: 2026-05-14 after project initialization*