# Testing Patterns

**Analysis Date:** 2026-05-14

## Test Framework

**Runner:**
- Framework: RSpec 3.x (via `rspec-rails`)
- Configuration: `.rspec` requires `spec_helper`
- Config file: `spec/spec_helper.rb` and `spec/rails_helper.rb`

**Assertion Library:**
- Primary: RSpec expectations (`expect(...).to`)
- Secondary: Shoulda-matchers for Rails model/association assertions

**Run Commands:**
```bash
bundle exec rspec                           # Run all tests
bundle exec rspec --fail-fast               # Stop at first failure
bundle exec rspec spec/models/user_spec.rb  # Run single file
bundle exec rspec spec/models/user_spec.rb:10  # Run specific line
```

## Test File Organization

**Location:**
- Model specs: `spec/models/[model_name]_spec.rb`
- Request specs (API endpoints): `spec/requests/api/v1/[resource_name]_spec.rb`
- Factory definitions: `spec/factories/[resource_name].rb` (plural)

**Naming:**
- Test files: `[subject]_spec.rb` (e.g., `user_spec.rb`, `events_spec.rb`)
- Describe blocks: "descriptive name" or class name (e.g., `RSpec.describe User, type: :model`)
- It blocks: plain language (e.g., `it "creates user and returns bearer token with strong password"`)

**Structure:**
```
spec/
├── factories/
│   ├── users.rb
│   ├── events.rb
│   └── ...
├── models/
│   ├── user_spec.rb
│   ├── event_spec.rb
│   └── ...
├── requests/
│   └── api/
│       └── v1/
│           ├── auth_spec.rb
│           ├── events_spec.rb
│           └── ...
├── rails_helper.rb
└── spec_helper.rb
```

## Test Structure

**Suite Organization:**
```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to have_many(:bookings) }
  it { is_expected.to validate_presence_of(:email) }

  describe "#normalize_email" do
    it "normalizes email before validation" do
      user.email = "  USER@Example.COM "
      user.valid?
      expect(user.email).to eq("user@example.com")
    end
  end
end
```

**Patterns:**
- Setup: factory-created fixtures (e.g., `let!(:user) { create(:user) }` or `create(:user, :admin)`)
- Teardown: automatic via `config.use_transactional_fixtures = true` in `rails_helper.rb`
- Assertions: Shoulda-matchers for model tests, JSON parsing for API tests

## Request Spec Structure (API Testing)

**Pattern:**
```ruby
require "rails_helper"

RSpec.describe "Events API", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:admin_headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: admin.id)}" } }

  describe "GET /api/v1/events" do
    let!(:future_event) { create(:event, starts_at: 3.days.from_now) }

    it "returns only upcoming events" do
      get "/api/v1/events"

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body).map { |event| event["id"] }
      expect(ids).to include(future_event.id)
    end
  end

  describe "POST /api/v1/events" do
    it "allows admin to create event" do
      params = attributes_for(:event).merge(starts_at: 2.days.from_now.iso8601)

      expect do
        post "/api/v1/events", params: params, headers: admin_headers
      end.to change(Event, :count).by(1)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["name"]).to eq(params[:name])
    end

    it "forbids regular user from creating event" do
      user_headers = { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" }
      post "/api/v1/events", params: attributes_for(:event), headers: user_headers

      expect(response).to have_http_status(:forbidden)
    end
  end
end
```

**Conventions:**
- Describe block per HTTP verb + path (e.g., `"GET /api/v1/events"`, `"POST /api/v1/events"`)
- Test successful cases, then error/authorization cases
- Use `expect { }.to change(Model, :count).by(n)` for side effects
- Parse JSON responses: `JSON.parse(response.body)`
- Assert on both HTTP status and response body

## Mocking

**Framework:** RSpec built-in mocks (`double`, `instance_double`, `mock_with :rspec`)

**Patterns:**
- Mock external services (e.g., would mock payment API if present)
- DO NOT mock database records; use factories instead
- DO NOT mock ActiveRecord finders; use real database queries

**Example of what NOT to do (anti-pattern):**
```ruby
# WRONG: Don't mock database lookups
allow(User).to receive(:find).and_return(user)

# RIGHT: Use factories and real queries
user = create(:user)
User.find(user.id)  # Real query
```

**Mock verification:**
- `verify_partial_doubles = true` configured in `spec/spec_helper.rb`
- Prevents mocking methods that don't exist on real objects

## Fixtures and Factories

**Test Data (Factories):**
Factories located in `spec/factories/[resource].rb` (plural).

**Example factory (`spec/factories/users.rb`):**
```ruby
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@#{Faker::Internet.domain_name}" }
    password { "SecurePass123!" }
    password_confirmation { "SecurePass123!" }
    role { :user }

    trait :admin do
      role { :admin }
    end
  end
end
```

**Usage patterns:**
```ruby
user = create(:user)                  # Create in database
admin = create(:user, :admin)         # Create with trait
user = build(:user)                   # Build in memory (no DB)
attrs = attributes_for(:user)         # Get hash of attributes
```

**Faker Integration:**
- Factories use Faker gem for realistic test data (e.g., `Faker::Internet.domain_name`, `Faker::Music.genre`)
- Sequences ensure uniqueness for constraints (e.g., `sequence(:email)`)

**Location:**
- All factories in `spec/factories/[resource].rb`
- Loaded automatically via FactoryBot Rails setup
- FactoryBot methods included globally via `config.include FactoryBot::Syntax::Methods`

## Coverage

**Requirements:** No enforced coverage target

**View Coverage:**
```bash
# Coverage NOT tracked by default
# To add coverage tracking, add SimpleCov gem and require in spec_helper.rb
```

**Current gaps observed:**
- No automatic coverage reporting
- Developers responsible for writing tests for their changes
- Pre-commit gate ensures all tests pass, but not coverage %, so manual coverage review needed

## Test Types

**Unit Tests (Model specs):**
- Scope: Model behavior, validations, associations, private methods
- Location: `spec/models/[model]_spec.rb`
- Use Shoulda-matchers for associations/validations
- Example: `spec/models/user_spec.rb` tests User validations, email normalization, role enum

**Integration Tests (Request specs):**
- Scope: Full HTTP request/response, including authentication and authorization
- Location: `spec/requests/api/v1/[resource]_spec.rb`
- Cover all CRUD operations and policy boundaries
- Example: `spec/requests/api/v1/events_spec.rb` tests GET, POST, PUT, DELETE with admin/user/guest roles

**E2E Tests:**
- Framework: Not used (this is API-only; no frontend in this repo)
- Manual QA or separate React frontend testing in `/react/music_events`

## Common Patterns

**Async Testing:**
Not heavily used; Rails uses synchronous request handling in tests.

**Error Testing:**
```ruby
# Test validation errors
it "rejects weak passwords" do
  params = { password: "weak" }
  post "/api/v1/auth/sign_up", params: params
  
  expect(response).to have_http_status(422)
  body = JSON.parse(response.body)
  expect(body["error_code"]).to eq("validation_error")
  expect(body["message"]).to include("at least 12 characters")
end

# Test authorization errors
it "forbids unauthorized access" do
  post "/api/v1/events", params: attributes_for(:event)
  
  expect(response).to have_http_status(:unauthorized)
  body = JSON.parse(response.body)
  expect(body["error_code"]).to eq("unauthorized")
end

# Test policy errors
it "forbids user from creating event" do
  user = create(:user)
  headers = { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" }
  post "/api/v1/events", params: attributes_for(:event), headers: headers
  
  expect(response).to have_http_status(:forbidden)
end
```

## Test Examples from Codebase

**Model spec (User validations):**
```ruby
RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
  it { is_expected.to allow_value("user@example.com").for(:email) }
  it { is_expected.not_to allow_value("invalid-email").for(:email) }
  
  it "normalizes email before validation" do
    user.email = "  USER@Example.COM "
    user.valid?
    expect(user.email).to eq("user@example.com")
  end
end
```

**Request spec (Auth + Authorization):**
```ruby
RSpec.describe "Events API", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:admin_headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: admin.id)}" } }

  describe "POST /api/v1/events" do
    it "allows admin to create event" do
      params = attributes_for(:event).merge(starts_at: 2.days.from_now.iso8601)
      
      expect { post "/api/v1/events", params: params, headers: admin_headers }
        .to change(Event, :count).by(1)

      expect(response).to have_http_status(:created)
    end

    it "forbids regular user" do
      user = create(:user)
      user_headers = { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" }
      post "/api/v1/events", params: attributes_for(:event), headers: user_headers

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects guest" do
      post "/api/v1/events", params: attributes_for(:event)
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
```

**Booking spec (Complex validation):**
```ruby
RSpec.describe "Bookings API", type: :request do
  let(:user) { create(:user) }
  let(:headers) { { "Authorization" => "Bearer #{JwtToken.encode(user_id: user.id)}" } }

  it "creates booking for upcoming event" do
    event = create(:event, starts_at: 2.days.from_now, tickets_capacity: 5)

    expect { post "/api/v1/events/#{event.id}/bookings", headers: headers }
      .to change(Booking, :count).by(1)

    expect(response).to have_http_status(:created)
    expect(event.reload.remaining_tickets).to eq(4)
  end

  it "rejects booking for past event" do
    event = create(:event, starts_at: 1.day.ago)
    post "/api/v1/events/#{event.id}/bookings", headers: headers

    expect(response).to have_http_status(422)
    body = JSON.parse(response.body)
    expect(body["message"]).to include("Event has already started")
  end

  it "rejects duplicate booking" do
    event = create(:event, starts_at: 2.days.from_now)
    create(:booking, user: user, event: event)

    post "/api/v1/events/#{event.id}/bookings", headers: headers

    expect(response).to have_http_status(409)
    body = JSON.parse(response.body)
    expect(body["error_code"]).to eq("duplicate_booking")
  end
end
```

## Test Coverage Gaps

**Observed gaps:**
1. **No coverage reporting** — No SimpleCov or similar; manual review required
2. **Limited edge cases** — Some boundary conditions may not be fully tested (e.g., concurrent bookings race conditions)
3. **No database constraint tests** — Unique index on (user_id, event_id) for Booking tested implicitly but could be explicit
4. **No load/performance tests** — No Lighthouse or k6 tests for API performance
5. **No schema validation tests** — Coordinates (latitude/longitude) validated in Rails but not tested against real-world edge cases (e.g., poles, date line)

**Recommendations to close gaps:**
- Add SimpleCov for coverage visibility and CI gates (e.g., 80%+ coverage requirement)
- Add explicit constraint tests for unique/foreign key validations
- Add performance benchmarks for list endpoints with large datasets
- Add more edge case tests for coordinate validation and time-zone handling

## CI/CD Hooks and Commit Gates

**Pre-Commit Gate:**
- Script: `.githooks/pre-commit`
- Hook path configured: `.githooks/` (configured via `core.hooksPath=.githooks`)
- Command: `bundle exec rspec --fail-fast`
- Behavior:
  - Runs on every `git commit`
  - If tests PASS: commit proceeds
  - If tests FAIL: commit is BLOCKED and rejected
  - `--fail-fast` stops at first failure to speed feedback

**Pre-Commit Script (``.githooks/pre-commit`):**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "[pre-commit] Running RSpec..."

if bundle exec rspec --fail-fast; then
  echo "[pre-commit] RSpec passed. Proceeding with commit."
  exit 0
else
  echo "[pre-commit] RSpec failed. Commit blocked."
  exit 1
fi
```

**Setup:**
- Hook is committed to repo in `.githooks/`
- Developers must configure Git to use it:
  ```bash
  git config core.hooksPath .githooks
  ```
- Can be bypassed with `git commit --no-verify` (not recommended)

**CI Pipeline:**
- Configured in `.github/workflows/` (if present) — not analyzed here
- Pre-commit gate in `.githooks/pre-commit` is the local barrier

## Test Database

**Configuration:**
- Test database automatically created from schema
- Transactional fixtures enabled: `config.use_transactional_fixtures = true` in `rails_helper.rb`
- Behavior: Each test runs in a transaction, automatically rolled back after
- Effect: Database is clean between tests; no manual cleanup needed

**Database Cleaner:**
- Dependency: `database_cleaner-active_record` in Gemfile
- Currently NOT used (transactional fixtures handle cleanup)
- Could be enabled for parallel test execution if needed in future

## Test Conventions Summary

| Category | Convention |
|----------|-----------|
| File location | `spec/[type]/[subject]_spec.rb` |
| Factory location | `spec/factories/[plural_resource].rb` |
| Describe block | HTTP verb + path or class name |
| Setup | Factory-created via `create(:resource)` or `let!` |
| Teardown | Automatic via transactional fixtures |
| Assertions | RSpec expectations + Shoulda-matchers |
| Mocking | RSpec doubles; NO database mocking |
| Auth testing | JWT bearer token in headers |
| Policy testing | Test role-based access via actual requests |
| Error testing | Assert on status + JSON error_code/message |

---

*Testing analysis: 2026-05-14*
