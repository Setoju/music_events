<!-- refreshed: 2026-05-14 -->
# Architecture

**Analysis Date:** 2026-05-14

## System Overview

The Music Events API is a **versioned Grape-based REST API** built on Rails, featuring role-based access control via Pundit policies, JWT authentication, and a clean layered architecture separating concerns between HTTP handling, business logic, data access, and authorization.

```
┌──────────────────────────────────────────────────────────────────┐
│                    HTTP Request → Grape API Layer                 │
│            Root (`app/api/root.rb`) → V1::Base (`app/api/v1/base.rb`)
├──────────────────┬──────────────────┬─────────────────────────────┤
│  /Events         │  /Artists        │  /Bookings, /Reviews, /Auth │
│ `v1/events.rb`   │ `v1/artists.rb`  │  `v1/bookings.rb`, etc.     │
└────────┬─────────┴────────┬─────────┴──────────────┬──────────────┘
         │                  │                        │
         ▼                  ▼                        ▼
┌──────────────────────────────────────────────────────────────────┐
│          Authorization & Authentication Layer                     │
│         AuthHelpers (`v1/helpers/auth_helpers.rb`)               │
│  authenticate! → current_user from JWT                           │
│  authorize_record! → Pundit policy check                         │
└──────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│              Business Logic & Data Layer                          │
│              Rails Models (`app/models/`)                         │
│  User, Event, Artist, Booking, Review, EventArtist              │
│  + Domain validations + Relationships + Scopes                   │
└────────┬─────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Authorization Layer                            │
│             Pundit Policies (`app/policies/`)                    │
│  Query methods: index?, show?, create?, update?, destroy?        │
└──────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│              Response Serialization (Entities)                    │
│           Grape Entities (`app/api/entities/`)                   │
│  Event, Artist, User, Booking, Review, AuthResponse             │
└──────────────────────────────────────────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────────────────────────────┐
│                   JSON Response to Client                         │
└──────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| **Root API** | Mount versioned API, error handling, swagger docs | `app/api/root.rb` |
| **V1 Base** | Mount all v1 endpoints (Events, Artists, Bookings, Reviews, Auth) | `app/api/v1/base.rb` |
| **Events** | Handle event CRUD, filtering by city/genre, list upcoming/past | `app/api/v1/events.rb` |
| **Artists** | Handle artist CRUD, list all artists | `app/api/v1/artists.rb` |
| **Bookings** | Create/cancel bookings for events, enforce availability | `app/api/v1/bookings.rb` |
| **Reviews** | Create/update/delete event reviews, list by event | `app/api/v1/reviews.rb` |
| **Auth** | User registration, login, JWT issuance, logout, password requirements | `app/api/v1/auth.rb` |
| **AuthHelpers** | Extract current_user from JWT, enforce authentication/authorization | `app/api/v1/helpers/auth_helpers.rb` |
| **JwtToken Service** | Encode/decode JWT tokens with expiration | `app/services/jwt_token.rb` |
| **User Model** | Store user credentials, role, validate password strength | `app/models/user.rb` |
| **Event Model** | Store event details (venue, city, capacity), calculate remaining tickets | `app/models/event.rb` |
| **Artist Model** | Store artist metadata (name, bio, genre, country) | `app/models/artist.rb` |
| **Booking Model** | Link user to event, enforce one booking per user, optimistic locking | `app/models/booking.rb` |
| **Review Model** | Link user to event with rating/comment, require booking + event completion | `app/models/review.rb` |
| **EventArtist** | Join table: many-to-many relationship between Event and Artist | `app/models/event_artist.rb` |
| **Policies** | Define query methods (index?, show?, create?) by role | `app/policies/*.rb` |
| **Entities** | Define response schema and nested relationships | `app/api/entities/*.rb` |

## Pattern Overview

**Overall:** Clean Layered Architecture with Grape-based Versioned API

**Key Characteristics:**
- **Versioning by path** (`/api/v1/*`) enables future v2 without breaking v1 clients
- **Separation of concerns**: Routes → Auth → Business Logic → Policy Check → Response
- **Pundit integration**: All resource mutations require explicit policy authorization
- **JWT with revocation**: Bearer tokens stored in Authorization header, revoked tokens tracked in `RevokedJwtToken` model
- **Role-based access**: Guest (unauthenticated) vs User (authenticated) vs Admin
- **Entity-based serialization**: Response contracts defined in Grape Entities, not in models

## Layers

### Layer 1: HTTP/API Entry Point
**Purpose:** Accept HTTP requests, validate parameters, mount versioned APIs

**Location:** `app/api/root.rb`, `config/routes.rb`

**Contains:** 
- Grape::API root class with error rescue handlers
- Version mounting (`/api/v1`)
- Swagger documentation generation
- Global error handlers for RecordNotFound, RecordInvalid, ValidationErrors, NotAuthorizedError

**Depends on:** Grape framework, Pundit, Rails error types

**Used by:** HTTP clients (React frontend, mobile apps)

### Layer 2: Versioned API Routes
**Purpose:** Define request methods (GET, POST, PUT, DELETE), parameter validation, response serialization

**Location:** `app/api/v1/*.rb` (events.rb, artists.rb, bookings.rb, reviews.rb, auth.rb)

**Contains:** 
- Resource routes with parameter specs
- Helpers injection (AuthHelpers)
- Request parameter validation
- Controller-like logic (authenticate, authorize, find/create/update records, present response)

**Depends on:** AuthHelpers, Models, Entities, Pundit

**Used by:** Layer 3 (Authentication/Authorization)

### Layer 3: Authentication & Authorization
**Purpose:** Extract JWT payload, identify current user, enforce Pundit policies

**Location:** `app/api/v1/helpers/auth_helpers.rb`, `app/policies/*.rb`

**Contains:** 
- `current_user` method: decodes JWT, retrieves User from DB, handles revoked tokens
- `authenticate!` method: ensures `current_user` is present, errors 401 if not
- `authorize_record!` method: calls Pundit policy, errors 403 if unauthorized
- `pundit_user` method: returns current_user or GuestUser (for unauthenticated checks)

**Depends on:** Models (User, RevokedJwtToken), Services (JwtToken), Pundit gem

**Used by:** All resource endpoints

### Layer 4: Domain Models & Business Logic
**Purpose:** Define data relationships, enforce domain rules, provide query scopes

**Location:** `app/models/*.rb`

**Contains:** 
- **User**: `has_secure_password`, role enum (user/admin), validations (email uniqueness, password strength)
- **Event**: venue, city, location geo-data, ticket capacity, start time, genre; scopes (upcoming, past, by_city, by_genre); computed properties (booked_tickets, remaining_tickets, upcoming?)
- **Artist**: name, bio, genre, country, website; scopes (by_genre, by_country)
- **Booking**: one booking per user per event; validates event is upcoming; pessimistic locking in create_for!
- **Review**: one review per user per event; validates user has booking; validates event has occurred; rating 1-5
- **EventArtist**: join table for Event ↔ Artist many-to-many
- **RevokedJwtToken**: tracks revoked JWT tokens (jti, exp) for logout support

**Depends on:** Rails Active Record, custom validators, JWT claims handling

**Used by:** Routes, Policies, Services

### Layer 5: Authorization Policies
**Purpose:** Define who can perform what action on which resource

**Location:** `app/policies/*.rb` (inherits from ApplicationPolicy)

**Contains:** Query methods (index?, show?, create?, update?, destroy?) that return true/false

**Patterns:**
- **Public read**: `index?`, `show?` return true (anyone can view)
- **Admin write**: `create?`, `update?`, `destroy?` require admin? role
- **Owner-scoped**: Booking/Review methods check `user == record.user` for mutation
- **Authenticated only**: Some actions require `authenticated?`

**Depends on:** ApplicationPolicy, current_user context

**Used by:** AuthHelpers.authorize_record!

### Layer 6: Response Serialization (Entities)
**Purpose:** Define JSON response schema and nested relationships

**Location:** `app/api/entities/*.rb`

**Contains:** 
- **User**: id, email, role
- **Event**: id, name, venue, city, geo-coordinates, genre, start_at, ticket_price, capacity, remaining_tickets, description, nested artist array
- **Artist**: id, name, bio, genre, country, website
- **Booking**: id, user_id, event_id, created_at, nested user, nested event
- **Review**: id, user_id, event_id, rating, comment, created_at, nested user
- **AuthResponse**: token (JWT string), user entity

**Depends on:** Grape::Entity, nested entity declarations

**Used by:** Routes to `present(record, with: Entities::ClassName)`

## Data Flow

### Primary Request Path: Create Event

1. **Client sends**: `POST /api/v1/events` with body (name, venue, city, starts_at, etc.)
2. **Route processing** (`app/api/v1/events.rb:post`): 
   - Extracts params, validates types/presence
   - Calls `authenticate!` helper → 401 if no valid JWT
3. **Authentication** (`AuthHelpers#authenticate!`): 
   - Calls `current_user` → decodes JWT bearer token → retrieves User from DB or returns nil
   - Errors 401 if `current_user` is nil
4. **Authorization** (`authorize_record!(Event, :create?)`): 
   - Calls `Pundit.authorize(pundit_user, Event, :create?)`
   - Calls `EventPolicy#create?` → returns true only if `admin?`
   - Errors 403 if false
5. **Business Logic** (`Event.create!(declared(params))`): 
   - Creates Event record with validated fields
   - Runs model validations (name/venue/city/starts_at presence, etc.)
   - Raises ActiveRecord::RecordInvalid if validation fails
6. **Error Handling** (Root-level rescue): 
   - Catches RecordInvalid, responds with error_code: "validation_error", status: 422
7. **Response** (`present event, with: Entities::Event`): 
   - Serializes Event to JSON using Entities::Event schema
   - Includes nested :artists array
   - Returns 201 Created with location header

**Example curl:**
```bash
curl -X POST http://localhost:3000/api/v1/events \
  -H "Authorization: Bearer eyJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jazz Night 2026",
    "venue": "Blue Note",
    "city": "New York",
    "starts_at": "2026-06-15T20:00:00Z",
    "genre": "Jazz",
    "ticket_price": 50,
    "tickets_capacity": 200
  }'
```

### Booking Flow: Create Booking

1. **Client sends**: `POST /api/v1/events/:event_id/bookings`
2. **Route** (`app/api/v1/bookings.rb:post`):
   - Calls `authenticate!` → 401 if not logged in
   - Finds Event by event_id
   - Checks duplicate booking (current_user.bookings.exists?(event_id))
   - Checks ticket availability (event.remaining_tickets > 0)
   - Calls `Booking.create_for!(user: current_user, event: event)`
3. **Booking Model** (`create_for!`):
   - Wraps in transaction
   - Acquires pessimistic lock on Event row (`event.with_lock`)
   - Calls `booking.save!` which triggers validations:
     - `:event_must_be_upcoming` → validates event.starts_at >= Time.current
     - `:user_id uniqueness scoped to event_id` → double-check duplicate
4. **Response** (`present booking, with: Entities::Booking`):
   - Serializes Booking with nested user and event
   - Returns 201 Created
5. **Error Handling**:
   - Duplicate booking → 409 Conflict (duplicate_booking)
   - No tickets → 409 Conflict (no_tickets_available)
   - ActiveRecord::RecordNotUnique → 409 Conflict (duplicate_booking)

### Review Flow: Create Review

1. **Client sends**: `POST /api/v1/events/:event_id/reviews` with body (rating: 1-5, comment)
2. **Route** (`app/api/v1/reviews.rb:post`):
   - Calls `authenticate!` → 401
   - Calls `authorize_record!(Review, :create?)` → calls `ReviewPolicy#create?` → checks `authenticated?`
   - Finds Event
   - Creates Review with user: current_user, event: event, rating, comment
3. **Review Model validations**:
   - `:user_must_have_booking` → checks Booking.exists?(user_id, event_id) → must exist
   - `:event_must_have_started` → checks event.starts_at <= Time.current → must have occurred
   - `:uniqueness of user_id scoped to event_id` → one review per user per event
4. **Response**: Serializes to Entities::Review

**State Management:**
- **JWT tokens**: Stored client-side, sent with every request in Authorization header
- **Revoked tokens**: Checked on every request via `RevokedJwtToken.revoked?(jti)` in current_token_payload
- **No session state**: Stateless API (no server-side sessions)

## Key Abstractions

### Pundit Authorization Boundary
**Purpose:** Centralize access control logic, separate from business logic

**Examples:**
- `EventPolicy#create?` → only admin can create events
- `BookingPolicy#destroy?` → only booking owner or admin can cancel
- `ReviewPolicy#update?` → only review author can edit

**Pattern:** Every resource mutation calls `authorize_record!(record, :action?)` before executing

### Grape Entities (Response Contracts)
**Purpose:** Define what fields are exposed in JSON, prevent accidental data leakage

**Examples:**
- `User` entity: id, email, role (never exposes password hash)
- `Event` entity: includes nested `artists` array, but not internal state
- `Booking` entity: includes both user and event for complete context

**Pattern:** Use `using:` to nest entities, `expose` to define fields

### JWT Token Flow
**Purpose:** Stateless authentication without sessions

**Encode** (`JwtToken.encode`):
```ruby
{
  user_id: <uid>,      # Payload
  exp: <future_time>,  # Expiration
  iat: <now>,          # Issued-at
  jti: <uuid>          # JWT ID (for revocation)
}
```

**Decode** (`JwtToken.decode`):
- Verifies signature
- Validates expiration (exp)
- Returns nil if invalid/expired/malformed

**Revocation** (`RevokedJwtToken.revoke!`):
- Stores jti + exp in DB on logout
- Checked on every request: `RevokedJwtToken.revoked?(jti)`

### GuestUser Adapter
**Purpose:** Safely handle unauthenticated requests in Pundit policies

**Behavior:** Object that responds to `admin?` and `user?` methods, always returns false

**Usage:** `pundit_user` returns `current_user || GuestUser.new`, ensuring policies don't crash on nil

## Entry Points

### POST /api/v1/auth/sign_up
**Triggers:** User registration

**Auth:** None (public)

**Flow:**
1. Validates email/password/password_confirmation
2. Creates User with role: :user
3. Encodes JWT with user_id
4. Returns token + user entity
5. Returns 201 Created

### POST /api/v1/auth/sign_in
**Triggers:** User login

**Auth:** None (public)

**Flow:**
1. Finds User by normalized email
2. Authenticates password with bcrypt
3. Encodes JWT with user_id
4. Returns token + user entity
5. Returns 200 OK

### GET /api/v1/auth/me
**Triggers:** Fetch current authenticated user

**Auth:** Bearer JWT required

**Flow:**
1. Calls authenticate! → 401 if no token
2. Returns current_user entity

### DELETE /api/v1/auth/logout
**Triggers:** Revoke JWT

**Auth:** Bearer JWT required

**Flow:**
1. Extracts jti and exp from token
2. Stores in RevokedJwtToken table
3. Returns 200 with success message

### GET /api/v1/events
**Triggers:** List upcoming events (with optional filtering)

**Auth:** None (public read)

**Flow:**
1. Calls `authorize_record!(Event, :index?)` → EventPolicy#index? → always true
2. Queries Event.upcoming.includes(:artists)
3. Applies optional filters (:city, :genre)
4. Presents array of Event entities
5. Returns 200 OK

### POST /api/v1/events/:event_id/bookings
**Triggers:** Create booking for event

**Auth:** Bearer JWT required

**Flow:**
1. authenticate! → 401
2. Finds Event
3. Checks duplicate booking → 409
4. Checks ticket availability → 409
5. Creates Booking with pessimistic lock
6. Presents Booking entity
7. Returns 201 Created

## Architectural Constraints

- **Threading:** Single-threaded event loop (Rails Puma default). Booking uses pessimistic locking (`event.with_lock`) to prevent race conditions on ticket capacity checks.
- **Global state:** `GuestUser` singleton per request, no server-side session storage (stateless API)
- **Circular imports:** No known circular dependencies between models (one-directional relationships)
- **No N+1 queries:** Routes use `.includes()` for eager loading (e.g., `Event.upcoming.includes(:artists)`)
- **JWT expiration:** 24 hours by default (configurable in JwtToken service)
- **Revocation overhead:** Lookup in RevokedJwtToken table on every request (consider caching in production)

## Anti-Patterns

### Race Condition on Ticket Booking

**What happens:** Two users simultaneously attempt to book the last ticket for an event. Without locking, both bookings succeed even though only 1 ticket remains.

**Why it's wrong:** Violates Event.tickets_capacity invariant, causes overbooking.

**Do this instead:** Use pessimistic locking as implemented in `Booking.create_for!` (`event.with_lock { booking.save! }`). This acquires a row lock on the Event, serializing concurrent bookings.

### Direct Password Access in Entities

**What happens:** If `Entities::User` exposed `password_hash` or `encrypted_password` in JSON responses.

**Why it's wrong:** Leaks password hashes to clients (could enable offline cracking).

**Do this instead:** Only expose `id, email, role` in User entity (as currently done). Use `has_secure_password` to hash on save.

### Missing Authorization Checks

**What happens:** If a route forgot to call `authorize_record!`, e.g., allowing any authenticated user to delete events.

**Why it's wrong:** Violates business rules (only admins should manage events).

**Do this instead:** Every mutation route (POST, PUT, DELETE) must call `authorize_record!(record, :action?)` before executing. Tests should verify policy enforcement.

## Error Handling

**Strategy:** Centralized Grape error handlers in `app/api/root.rb` with consistent JSON schema.

**Patterns:**

```ruby
# Standard error response format
{
  message: "Human-readable message",
  error_code: "machine_readable_code",
  status: <http_status>
}
```

**Handled exceptions:**

| Exception | Code | Status | Meaning |
|-----------|------|--------|---------|
| `ActiveRecord::RecordNotFound` | not_found | 404 | Resource doesn't exist |
| `ActiveRecord::RecordInvalid` | validation_error | 422 | Model validation failed |
| `Grape::Exceptions::ValidationErrors` | bad_request | 400 | Parameter validation failed |
| `Pundit::NotAuthorizedError` | forbidden | 403 | User lacks permission |
| Custom in routes | duplicate_booking | 409 | User already booked this event |
| Custom in routes | no_tickets_available | 409 | Event sold out |
| Custom in routes | unauthorized | 401 | Authentication required |

## Cross-Cutting Concerns

**Logging:** Rails logger (configured in `config/environments/*.rb`), no structured logging currently.

**Validation:** 
- Model validators: `PasswordStrengthValidator` for password rules
- Grape param validators: `:type`, `:presence`, `:values`
- Model associations validators: `:uniqueness`, `:presence`

**Authentication:** 
- JWT tokens from `JwtToken` service
- Bearer scheme (Authorization: Bearer <token>)
- Revocation via `RevokedJwtToken` table
- Expiration: 24 hours

**CORS:** Configured in `config/initializers/cors.rb` to allow all origins (development-friendly, should be restricted in production).

---

*Architecture analysis: 2026-05-14*
