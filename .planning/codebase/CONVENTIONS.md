# Coding Conventions

**Analysis Date:** 2026-05-14

## Naming Patterns

**Files:**
- Ruby files: `snake_case.rb` (e.g., `user_policy.rb`, `jwt_token.rb`)
- Models: singular noun (e.g., `user.rb`, `event.rb`, `booking.rb`)
- Policies: singular noun + `_policy.rb` (e.g., `event_policy.rb`, `booking_policy.rb`) in `app/policies/`
- Entities (Grape response contracts): `[Resource].rb` in `app/api/entities/` (e.g., `event.rb`)
- API endpoints (Grape resources): `[Resource].rb` in `app/api/v1/` (e.g., `events.rb`, `bookings.rb`)
- Factories: plural noun + `.rb` in `spec/factories/` (e.g., `users.rb`, `events.rb`)
- Specs: file being tested + `_spec.rb` (e.g., `user_spec.rb`, `events_spec.rb`)

**Functions/Methods:**
- Methods: `snake_case` (e.g., `authenticate!`, `authorize_record!`, `remaining_tickets`)
- Private methods: prefix with underscore or `private` keyword (e.g., `private def normalize_email`)
- Predicates (boolean): `snake_case?` (e.g., `admin?`, `authenticated?`, `upcoming?`, `valid?`)
- Bang methods: used for methods that modify state or raise errors (e.g., `authenticate!`, `revoke_current_token!`, `create_for!`)

**Variables:**
- Local variables: `snake_case` (e.g., `admin_headers`, `user_headers`, `bearer_token`)
- Instance variables: `@snake_case` (e.g., `@current_user`, `@current_token_payload`)
- Constants: `UPPER_SNAKE_CASE` (e.g., `ALGORITHM = "HS256"`, `DEFAULT_EXPIRATION = 24.hours`)

**Classes:**
- Classes: `PascalCase` (e.g., `User`, `Event`, `Booking`, `JwtToken`)
- Modules: `PascalCase` (e.g., `V1`, `AuthHelpers`, `Entities`)
- Enums: singular, snake_case in `enum` definition (e.g., `enum :role, { user: 0, admin: 1 }`)

## Code Style

**Formatting:**
- Tool: Rubocop with `rubocop-rails-omakase` preset (Omakase Ruby styling for Rails)
- Configuration: `.rubocop.yml` inherits from `rubocop-rails-omakase:rubocop.yml`
- Line length: 120 chars (Omakase default)
- Indentation: 2 spaces
- No trailing commas in arrays/hashes unless multiline

**Linting:**
- Tool: Rubocop (applied via `bin/rubocop`)
- Rules: Follow `rubocop-rails-omakase` (Rails best practices and style)
- Pre-commit: Rubocop linting is NOT gated; only RSpec tests block commits (see CI/CD section)

**Run Rubocop:**
```bash
bundle exec rubocop              # Check all files
bundle exec rubocop -a           # Auto-fix violations
bin/rubocop                       # Shorthand
```

## Import Organization

**Order:**
1. Standard library (e.g., `require "rails_helper"`, `require "spec_helper"`)
2. Rails/Gems (e.g., `require 'rspec/rails'`, `require 'shoulda/matchers'`)
3. App code (e.g., `require_relative '../config/environment'`)
4. No blank lines between groups in typical Rails files

**Path Aliases:**
- No custom path aliases used; standard Rails/Grape conventions apply
- API modules: `V1::*` for versioned endpoints
- Entities: `Entities::*` for response contracts

## Error Handling

**Patterns:**
- Grape API errors use `error!(error_response, status_code)` method
- Error responses are dictionaries with `message`, `error_code`, and `status` keys (see `app/api/root.rb`)
- ActiveRecord errors rescued by Grape (e.g., `ActiveRecord::RecordNotFound`, `ActiveRecord::RecordInvalid`)
- ActiveRecord validation errors transformed to Grape error format with full_messages
- JWT decode errors caught and return `nil` (permissive; handled by auth helpers)

**Example error structure (`app/api/root.rb`):**
```ruby
rescue_from ActiveRecord::RecordNotFound do
  error_response = {
    message: "Resource not found",
    error_code: "not_found",
    status: 404
  }
  error!(error_response, 404)
end

rescue_from ActiveRecord::RecordInvalid do |e|
  error_response = {
    message: e.record.errors.full_messages.join(", "),
    error_code: "validation_error",
    status: 422
  }
  error!(error_response, 422)
end
```

## Logging

**Framework:** Standard Rails logger (via `Rails.logger`)

**Patterns:**
- Minimal logging in models and services
- Authentication debug logging not used (tokens not logged)
- Errors logged by Rails error handler, not manually in API code
- SQL queries logged in development (Rails default)

## Comments

**When to Comment:**
- Comments used sparingly; code should be self-documenting
- Grape documentation strings used for API endpoints (via `desc` and `documentation:` options)
- Comments explain WHY, not WHAT (e.g., business rules, constraints)

**Grape API Documentation:**
- Each resource and action includes `desc` with description
- Parameters documented via `documentation:` hash (e.g., `type: "integer", desc: "Event identifier"`)
- Responses documented via `success:` and error codes via rescue handlers
- Example: `app/api/v1/events.rb` and `app/api/entities/event.rb`

**JSDoc/TSDoc:**
- Not used (Ruby/Rails conventions used instead)
- Grape entities use inline `documentation:` metadata for OpenAPI/Swagger generation

## Function Design

**Size:** 
- Methods typically 5-20 lines; longer methods split into private helpers
- Grape actions (endpoints): 5-15 lines (business logic delegated to models/services)

**Parameters:** 
- Use `**kwargs` for Grape `params` declarations (e.g., `post do` blocks)
- Models accept simple parameter lists or hashes
- Services (e.g., `JwtToken`) use class methods with keyword arguments (`encode(payload = {}, exp: ..., jti: ..., **claims)`)

**Return Values:** 
- Methods return the modified resource or `true/false` for predicates
- Grape endpoints return response entities via `present` method
- Services return typed values (e.g., `JwtToken.encode` returns string token, `JwtToken.decode` returns Hash or nil)

## Module Design

**Exports:** 
- Models define relationships and validations at top level
- Services use class methods (e.g., `JwtToken.encode`, `JwtToken.decode`)
- Policies are instantiated with `Pundit.authorize(pundit_user, record, query)` at the endpoint level
- Helpers included via `helpers [ModuleName]` in Grape resources

**Barrel Files:** 
- Not used; each file exports its single class/module
- API v1 mounts all resources in `app/api/v1/base.rb`

## Authorization & Authorization Patterns

**Pundit Integration:**
- All record-level authorization via `authorize_record!(record, query)` in endpoints
- Queries are method names: `index?`, `show?`, `create?`, `update?`, `destroy?`
- Policies in `app/policies/` inherit from `ApplicationPolicy`
- User roles checked via `admin?`, `authenticated?` helper methods

**Example policy (`app/policies/event_policy.rb`):**
```ruby
class EventPolicy < ApplicationPolicy
  def index?
    true  # Public read
  end

  def show?
    true  # Public read
  end

  def create?
    admin?  # Admin-only write
  end

  def update?
    admin?
  end

  def destroy?
    admin?
  end
end
```

**Example endpoint authorization (`app/api/v1/events.rb`):**
```ruby
get do
  authorize_record!(Event, :index?)
  events = Event.upcoming.includes(:artists)
  present events, with: Entities::Event
end

post do
  authenticate!
  authorize_record!(Event, :create?)
  event = Event.create!(declared(params))
  present event, with: Entities::Event
end
```

## Database & Model Design

**Relationships:**
- Use `has_many :through` for join table queries (e.g., `has_many :booked_events, through: :bookings`)
- Use `dependent: :destroy` for cascading deletes where appropriate

**Validations:**
- Database constraints AND model validations both used
- `validates_presence_of`, `validates_uniqueness_of`, `validates_with` patterns
- Custom validators in `app/validators/` (e.g., `PasswordStrengthValidator`)

**Scopes:**
- Named scopes prefixed with `.` (e.g., `Event.upcoming`, `Event.by_city("Kyiv")`)
- Scopes are chainable and include eager loading (`.includes`)
- Example: `scope :upcoming, -> { where("starts_at >= ?", Time.current).order(:starts_at) }`

**Callbacks:**
- `before_validation` used for data normalization (e.g., `normalize_email`)
- Avoid complex logic in callbacks; delegate to methods

## Service Layer

**JwtToken Service (`app/services/jwt_token.rb`):**
- Encapsulates JWT encoding/decoding logic
- Class methods: `encode`, `decode`
- Single responsibility: token lifecycle management
- Does not handle revocation (delegated to `RevokedJwtToken` model)

**Pagination & Filtering:**
- Implemented via scope chains (e.g., `Event.upcoming.by_city(city).by_genre(genre)`)
- No separate service layer for queries

## Entity/Presenter Layer

**Entities (Grape responses):**
- Define API response contracts
- Located in `app/api/entities/`
- Use `expose` to control which fields are returned
- Include `documentation:` metadata for OpenAPI/Swagger

**Example entity (`app/api/entities/event.rb`):**
```ruby
module Entities
  class Event < Grape::Entity
    expose :id, documentation: { type: "integer", desc: "Event identifier" }
    expose :name, documentation: { type: "string", desc: "Event name" }
    expose :artists,
           using: Entities::Artist,
           documentation: { type: "Entities::Artist", is_array: true, desc: "Performing artists" }
  end
end
```

---

*Convention analysis: 2026-05-14*
