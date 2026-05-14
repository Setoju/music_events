# Codebase Structure

**Analysis Date:** 2026-05-14

## Directory Layout

```
music_events/
├── app/                              # Application code
│   ├── api/                          # Grape API routes and entities
│   │   ├── root.rb                   # Root API class, error handlers, swagger
│   │   ├── v1/                       # V1 API endpoints
│   │   │   ├── base.rb               # Mount all V1 resources
│   │   │   ├── events.rb             # GET/POST/PUT /events, /events/:id, /events/past
│   │   │   ├── artists.rb            # GET/POST/PUT /artists, /artists/:id
│   │   │   ├── bookings.rb           # POST/DELETE /events/:event_id/bookings
│   │   │   ├── reviews.rb            # GET/POST/PUT/DELETE /events/:event_id/reviews
│   │   │   ├── auth.rb               # POST /auth/sign_up, /sign_in; DELETE /logout; GET /me
│   │   │   └── helpers/
│   │   │       └── auth_helpers.rb   # current_user, authenticate!, authorize_record!, bearer_token extraction
│   │   └── entities/                 # Response serialization schemas
│   │       ├── user.rb               # User entity: id, email, role
│   │       ├── event.rb              # Event entity: id, name, venue, city, artists[], remaining_tickets
│   │       ├── artist.rb             # Artist entity: id, name, bio, genre, country, website
│   │       ├── booking.rb            # Booking entity: id, user_id, event_id, user, event
│   │       ├── review.rb             # Review entity: id, user_id, event_id, rating, comment, user
│   │       ├── auth_response.rb      # Auth entity: token, user
│   │       └── error.rb              # Error entity: message, error_code, status
│   │
│   ├── models/                       # Domain models (Rails ActiveRecord)
│   │   ├── application_record.rb     # Base class for all models
│   │   ├── user.rb                   # has_secure_password, role enum (user/admin)
│   │   ├── event.rb                  # venue, city, capacity, start_at, scopes (upcoming/past)
│   │   ├── artist.rb                 # name, bio, genre, country, website
│   │   ├── booking.rb                # user-event join with pessimistic lock create_for!
│   │   ├── review.rb                 # user-event review with rating (1-5), validations
│   │   ├── event_artist.rb           # join table: event ↔ artist
│   │   ├── guest_user.rb             # Adapter for unauthenticated requests (responds to admin?, user?)
│   │   ├── revoked_jwt_token.rb      # Tracks revoked JWTs by jti for logout
│   │   └── concerns/                 # Shared model concerns (empty currently)
│   │
│   ├── policies/                     # Pundit authorization policies
│   │   ├── application_policy.rb     # Base policy: admin?, authenticated? helpers
│   │   ├── event_policy.rb           # index?/show? true; create?/update?/destroy? → admin?
│   │   ├── artist_policy.rb          # same pattern
│   │   ├── booking_policy.rb         # index?/create? → authenticated?; show?/destroy? → user == record.user
│   │   └── review_policy.rb          # index?/show? true; create? → authenticated?; update?/destroy? → user == record.user
│   │
│   ├── services/                     # Business logic services
│   │   └── jwt_token.rb              # Encode/decode JWT; HS256 algorithm; 24h expiration
│   │
│   ├── validators/                   # Custom validators
│   │   └── password_strength_validator.rb  # Enforce 9+ chars, uppercase, lowercase, digit, special char
│   │
│   ├── controllers/                  # Rails controllers (minimal, mostly Grape-handled)
│   │   ├── application_controller.rb
│   │   └── concerns/
│   │
│   ├── jobs/                         # Background job stubs (empty currently)
│   ├── mailers/                      # Email stubs (empty currently)
│   └── views/                        # View stubs (not used in API)
│
├── config/                           # Rails configuration
│   ├── routes.rb                     # Mount Grape root API
│   ├── application.rb                # Rails app config
│   ├── boot.rb                       # Rails boot sequence
│   ├── environment.rb                # Environment defaults
│   ├── puma.rb                       # Puma server config
│   ├── database.yml                  # Database connection (uses rails-credentials for production)
│   ├── initializers/
│   │   ├── cors.rb                   # CORS middleware: allow all origins (for development)
│   │   ├── filter_parameter_logging.rb  # Log filter config
│   │   └── rack_attack.rb            # Rate limiting config (if enabled)
│   └── environments/
│       ├── development.rb            # Development settings
│       ├── production.rb             # Production settings
│       └── test.rb                   # Test settings
│
├── db/                               # Database
│   ├── schema.rb                     # Rails generated schema (do not edit)
│   ├── seeds.rb                      # Database seed data
│   └── migrate/                      # Database migrations (timestamps_table_name.rb)
│       ├── 20260428112702_create_events.rb
│       ├── 20260428131109_create_artists.rb
│       ├── ...                       # Add new migrations here
│       └── latest_migration.rb       # Always add at end
│
├── spec/                             # RSpec test suite
│   ├── spec_helper.rb                # RSpec config
│   ├── rails_helper.rb               # Rails + RSpec setup
│   ├── factories/                    # FactoryBot factories (define test data)
│   ├── models/                       # Model specs (relationships, validations, scopes)
│   └── requests/                     # API request specs (endpoint testing)
│
├── Gemfile                           # Ruby dependencies
├── Gemfile.lock                      # Locked dependency versions
├── config.ru                         # Rack app entry point
├── Dockerfile                        # Docker image definition
└── Rakefile                          # Rails rake tasks
```

## Directory Purposes

### app/api/ — API Route Definitions & Response Contracts

**Purpose:** Define HTTP endpoints (routes), parameter validation, authentication/authorization, response serialization.

**Contains:** 
- `root.rb`: Grape::API root, error handlers, Swagger docs
- `v1/base.rb`: Mount all v1 resources
- `v1/events.rb`, `v1/artists.rb`, etc.: Individual resource routes (GET, POST, PUT, DELETE)
- `v1/helpers/auth_helpers.rb`: Extract JWT, identify current_user, enforce Pundit policies
- `entities/`: Grape::Entity schemas for serializing responses

**Why separate:** Routes are HTTP-specific (status codes, headers), while models are domain-specific (business rules). This separation makes models reusable outside HTTP context.

### app/models/ — Domain Models & Business Logic

**Purpose:** Define data entities, relationships, validations, and domain rules.

**Contains:** 
- `user.rb`, `event.rb`, `artist.rb`, `booking.rb`, `review.rb`: Domain objects
- `application_record.rb`: Base class for all models
- `event_artist.rb`: Join table for Event ↔ Artist many-to-many
- `guest_user.rb`: Adapter for nil current_user (responds to admin?, user?)
- `revoked_jwt_token.rb`: Track logged-out JWTs

**Why separate:** Models represent the business domain and can be tested without HTTP context. Relationships and validations live here.

### app/policies/ — Authorization Rules (Pundit)

**Purpose:** Centralize access control logic by resource.

**Contains:** 
- `application_policy.rb`: Base policy with role helpers (admin?, authenticated?)
- One policy per resource (EventPolicy, ArtistPolicy, BookingPolicy, ReviewPolicy)

**Pattern:** Each policy defines query methods (index?, show?, create?, update?, destroy?) that return true/false.

**Why separate:** Authorization is cross-cutting and complex. Centralizing in policies makes it auditable and testable.

### app/services/ — Business Logic Services

**Purpose:** Encapsulate complex operations that don't belong in models or routes.

**Contains:** 
- `jwt_token.rb`: JWT encode/decode with HS256 and expiration

**When to add:** For operations involving multiple models or external services (e.g., payment processing, file uploads).

### app/validators/ — Custom Validation Rules

**Purpose:** Reusable model validation logic.

**Contains:** 
- `password_strength_validator.rb`: Enforce password rules (9+ chars, uppercase, lowercase, digit, special)

**When to add:** For complex validations used in multiple models or tests.

### config/ — Rails Application Configuration

**Purpose:** Configure database, middleware, environment-specific settings, and API mounting.

**Key files:**
- `routes.rb`: Mount Grape API at root
- `initializers/cors.rb`: CORS middleware (allow all origins in development)
- `database.yml`: Database connection settings
- `environments/`: Dev/test/production-specific config
- `credentials.yml.enc`: Encrypted secrets (production database URL, API keys, etc.)

### db/ — Database Schema & Migrations

**Purpose:** Define database schema through migrations, ensure reproducible database state.

**Key files:**
- `migrate/`: Add new migrations here (one per table/change)
- `schema.rb`: Auto-generated, **do not edit directly**
- `seeds.rb`: Seed development data

**Pattern:** Always create migrations for schema changes, never edit schema.rb directly.

### spec/ — Test Suite (RSpec)

**Purpose:** Test models, validations, policies, and API endpoints.

**Structure:**
- `factories/`: FactoryBot definitions for test data
- `models/`: Model specs (relationships, validations, scopes)
- `requests/`: Request specs (API endpoint testing)

## Key File Locations

### Entry Points

| File | Purpose |
|------|---------|
| `config/routes.rb` | Mount Grape API at root path `/` |
| `app/api/root.rb` | Grape::API root with error handlers, version mounting, Swagger docs |
| `config.ru` | Rack app for Puma to run |

### Configuration

| File | Purpose |
|------|---------|
| `config/application.rb` | Rails app settings (load paths, autoload, gems) |
| `config/database.yml` | Database connection (rails-credentials overrides in production) |
| `config/initializers/cors.rb` | CORS middleware (allow all origins) |
| `config/puma.rb` | Puma server threads, workers |

### Core Logic

| File | Purpose |
|------|---------|
| `app/models/user.rb` | User entity, authentication |
| `app/models/event.rb` | Event entity, scopes (upcoming, past), computed properties |
| `app/models/booking.rb` | Booking with pessimistic lock, validations |
| `app/services/jwt_token.rb` | JWT encode/decode |
| `app/api/v1/helpers/auth_helpers.rb` | Extract JWT, identify user, enforce authorization |

### Testing

| File | Purpose |
|------|---------|
| `spec/rails_helper.rb` | RSpec + Rails setup |
| `spec/factories/` | FactoryBot model factories |
| `spec/models/` | Model tests |
| `spec/requests/` | API endpoint tests |

## Naming Conventions

### Files

**Models:** Singular, snake_case
- `user.rb`, `event.rb`, `artist.rb`, `booking.rb`, `review.rb`

**Migrations:** `TIMESTAMP_action_on_table.rb`
- `20260428112702_create_events.rb`
- `20260501093015_add_genre_to_events.rb`
- `20260502145830_create_booking_unique_index.rb`

**Routes:** Plural, snake_case (resource names)
- `events.rb`, `artists.rb`, `bookings.rb`, `reviews.rb`, `auth.rb`

**Entities:** Singular, CamelCase, in `Entities::` namespace
- `Entities::Event`, `Entities::User`, `Entities::Booking`

**Policies:** Singular + "Policy", CamelCase
- `EventPolicy`, `UserPolicy`, `BookingPolicy`

**Validators:** Singular + "Validator", CamelCase, in `app/validators/`
- `PasswordStrengthValidator`

**Helpers:** Plural, snake_case, in `V1::Helpers::` namespace
- `AuthHelpers` in `v1/helpers/auth_helpers.rb`

### Directories

**Resource-scoped:** Plural form of resource
- `app/models/`, `app/policies/`, `app/api/v1/`

**Shared logic:** Singular form
- `app/services/`, `app/validators/`, `app/api/v1/helpers/`

**Concerns:** `concerns/` subdirectories (for shared mixins)
- `app/models/concerns/`, `app/controllers/concerns/`

### Code Style

**Constants:** UPPERCASE_SNAKE_CASE
- `RATING_RANGE = 1..5` in `Review`
- `HS256`, `DEFAULT_EXPIRATION` in `JwtToken`

**Methods:** snake_case, boolean methods end with ?
- `def upcoming?` in Event
- `def authenticate!` in AuthHelpers (exclamation for methods that raise)

**Variables:** snake_case
- `current_user`, `event_id`, `remaining_tickets`

## Where to Add New Code

### New Endpoint (e.g., /events/:id/cancel)

**Files to create/modify:**

1. **Add route:** `app/api/v1/events.rb` (if event-scoped) or `app/api/v1/new_resource.rb` (if new resource)
   ```ruby
   # app/api/v1/events.rb
   delete ":id/cancel" do
     authenticate!
     event = Event.find(params[:id])
     authorize_record!(event, :cancel?)  # New policy method
     event.update!(cancelled_at: Time.current)
     present event, with: Entities::Event
   end
   ```

2. **Add policy method:** `app/policies/event_policy.rb`
   ```ruby
   def cancel?
     admin?  # or your business rule
   end
   ```

3. **Update model if needed:** `app/models/event.rb`
   ```ruby
   validates :cancelled_at, comparison: { less_than_or_equal_to: :starts_at }
   ```

4. **Add entity fields if needed:** `app/api/entities/event.rb`
   ```ruby
   expose :cancelled_at, documentation: { type: "dateTime" }
   ```

5. **Add migration if schema change:** `db/migrate/TIMESTAMP_add_cancelled_at_to_events.rb`
   ```ruby
   def change
     add_column :events, :cancelled_at, :datetime
     add_index :events, :cancelled_at
   end
   ```

6. **Add tests:** `spec/requests/events_spec.rb`, `spec/policies/event_policy_spec.rb`

### New Resource (e.g., /venues)

**Files to create:**

1. **Create model:** `app/models/venue.rb`
   ```ruby
   class Venue < ApplicationRecord
     has_many :events
     validates :name, :city, :capacity, presence: true
   end
   ```

2. **Create migration:** `db/migrate/TIMESTAMP_create_venues.rb`

3. **Create entity:** `app/api/entities/venue.rb`
   ```ruby
   module Entities
     class Venue < Grape::Entity
       expose :id, :name, :city, :capacity
     end
   end
   ```

4. **Create policy:** `app/policies/venue_policy.rb`
   ```ruby
   class VenuePolicy < ApplicationPolicy
     def index?; true; end
     def show?; true; end
     def create?; admin?; end
     def update?; admin?; end
     def destroy?; admin?; end
   end
   ```

5. **Create routes:** `app/api/v1/venues.rb`
   ```ruby
   module V1
     class Venues < Grape::API
       helpers V1::Helpers::AuthHelpers
       resource :venues do
         get { authorize_record!(Venue, :index?); present Venue.all, with: Entities::Venue }
         post { authenticate!; authorize_record!(Venue, :create?); ... }
       end
     end
   end
   ```

6. **Mount in base:** `app/api/v1/base.rb`
   ```ruby
   mount V1::Venues
   ```

7. **Add tests:** `spec/requests/venues_spec.rb`, `spec/models/venue_spec.rb`, `spec/policies/venue_policy_spec.rb`

### New Validation Rule

**Files to create/modify:**

1. **Create validator:** `app/validators/venue_capacity_validator.rb`
   ```ruby
   class VenueCapacityValidator < ActiveModel::Validator
     def validate(record)
       if record.capacity < 10
         record.errors.add :capacity, "must be at least 10"
       end
     end
   end
   ```

2. **Use in model:** `app/models/venue.rb`
   ```ruby
   validates_with VenueCapacityValidator
   ```

### New Service Class

**Files to create:**

1. **Create service:** `app/services/booking_confirmation_mailer.rb`
   ```ruby
   class BookingConfirmationMailer
     def initialize(booking)
       @booking = booking
     end

     def send_email
       # Send confirmation logic
     end
   end
   ```

2. **Use in route:** `app/api/v1/bookings.rb`
   ```ruby
   BookingConfirmationMailer.new(booking).send_email
   ```

## Special Directories

### db/migrate/

**Purpose:** Version control database schema changes, ensure reproducible migrations.

**Important:** 
- Always create new migrations, never edit existing ones
- Always run pending migrations before deploying
- Rollback command: `rails db:rollback`

**Committed:** ✅ Yes (always commit migrations)

**Generated:** ❌ No (author-written)

### db/schema.rb

**Purpose:** Rails-generated representation of database schema.

**Important:**
- **DO NOT EDIT DIRECTLY** — regenerated by `rails db:migrate`
- Useful for reading current schema, but never modify by hand

**Committed:** ✅ Yes (commit after migrations)

**Generated:** ✅ Yes (by Rails)

### spec/factories/

**Purpose:** FactoryBot definitions for creating test objects.

**Pattern:** 
```ruby
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "SecurePass123!" }
    role { :user }
  end
end
```

**Committed:** ✅ Yes

**Generated:** ❌ No

### Gemfile & Gemfile.lock

**Purpose:** 
- `Gemfile`: Declare gem dependencies
- `Gemfile.lock`: Lock versions for reproducible installs

**Important:**
- **Commit both files** — ensures all developers use same versions
- Run `bundle install` after modifying Gemfile
- Never manually edit Gemfile.lock

**Committed:** ✅ Yes (both)

---

*Structure analysis: 2026-05-14*
