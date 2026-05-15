# Technology Stack

**Analysis Date:** 2026-05-14

## Languages

**Primary:**
- Ruby 3.x (inferred from Rails 8) - API backend, models, services, policies

**Secondary:**
- SQL (PostgreSQL dialect) - Data queries and migrations
- JSON - API request/response payloads

## Runtime

**Environment:**
- Rails 8.1.3 - Web framework and application runtime

**Package Manager:**
- Bundler - Ruby dependency manager
- Gemfile: `.perfection` lock file managed in `Gemfile.lock`

## Frameworks

**Core:**
- Rails 8.1.3 - Full-stack web framework configured as API-only
- Grape 1.x - RESTful API framework with versioning (`/api/v1/*`)
- Grape Entity - Response serialization and documentation
- Grape Swagger - API documentation generation

**Web Server:**
- Puma 5.0+ - Multi-threaded application server
  - Default: 3 threads per process (configurable via `RAILS_MAX_THREADS`)
  - Multi-process: Configurable via `WEB_CONCURRENCY` environment variable
  - Max connections: 5 (configurable via `RAILS_MAX_THREADS`)

**Testing:**
- RSpec Rails - Test framework for models, requests, and policies
- Factory Bot Rails - Test data factories
- Faker - Test data generation
- Shoulda Matchers - Active Record and Rails matchers
- Database Cleaner for Active Record - Test database isolation

**Build/Dev:**
- Bootsnap - Ruby boot time optimization
- Bundler Audit - Gem security auditing
- Brakeman - Static security vulnerability scanning
- RuboCop Rails Omakase - Style enforcement (Rails conventions)

## Key Dependencies

**Critical:**
- Rails 8.1.3 - Application framework
- pg 1.1+ - PostgreSQL adapter for Active Record
- Grape - API versioning and endpoint routing
- JWT - Token encoding/decoding for stateless authentication
- Pundit - Authorization policy framework (role-based access control)

**Authentication & Security:**
- bcrypt 3.1.7 - Password hashing for `has_secure_password`
- JWT - Bearer token creation and verification
- rack-attack - Rate limiting and IP blocking
- password_strength - Password validation and strength checking

**Infrastructure & Persistence:**
- solid_cache - Database-backed cache store (SQLite/PostgreSQL)
- solid_queue - Background job queue (database-backed)
- solid_cable - Action Cable adapter for real-time features (database-backed)
- image_processing 1.2 - Active Storage image transformations

**API & Middleware:**
- rack-cors - Cross-Origin Resource Sharing (CORS) configuration
- grape-swagger - OpenAPI/Swagger documentation generation

## Configuration

**Environment:**
- API-only Rails configuration: `config.api_only = true`
- API autoload paths: `app/api` directory added to `Rails.autoload_paths`
- Load defaults: Rails 8.1 (modern security and performance defaults)

**Build:**
- `Dockerfile` - Container image for production deployment
- `Kamal` - Deployment automation
- `.rubocop.yml` - Code style configuration
- `.brakeman.yml` - Security scanning configuration

**Secrets Management:**
- Rails credentials file: `config/credentials.yml.enc` (encrypted)
- Environment variables: Used for deployment-specific values (`DATABASE_URL`, `RAILS_MAX_THREADS`, `JOB_CONCURRENCY`, `WEB_CONCURRENCY`)

## Platform Requirements

**Development:**
- Ruby 3.x
- PostgreSQL 9.5+ (configurable host/port via `config/database.yml`)
- Bundler (gem dependency manager)
- Node.js optional (for asset pipeline, currently not used in API-only app)

**Production:**
- Docker container (see `Dockerfile`)
- PostgreSQL 9.5+ database
- Environment variables:
  - `DATABASE_URL` - PostgreSQL connection string
  - `RAILS_MASTER_KEY` - Encryption key for `credentials.yml.enc`
  - `RAILS_MAX_THREADS` - Thread pool size (default: 5)
  - `JOB_CONCURRENCY` - Background job workers (default: 1)
  - `WEB_CONCURRENCY` - Puma worker processes (default: 1)
  - `RAILS_ENV` - Environment (production/staging/development)

## Request Handling Architecture

**Request Flow:**
1. HTTP request enters Puma (threaded application server)
2. Rack middleware stack processes (CORS, attack prevention, parameter filtering)
3. Grape routing dispatches to versioned endpoint (`V1::Auth`, `V1::Events`, etc.)
4. Authentication middleware extracts JWT from Bearer token header
5. Authorization checks via Pundit policies
6. Active Record models interact with PostgreSQL
7. Response serialized via Grape Entity definitions
8. JSON returned to client

**Concurrency Model:**
- CRuby Global VM Lock (GVL) prevents true multi-threading
- Default: 3 threads per process (IO-bound concurrency)
- Multiple processes recommended for CPU-bound work
- Thread-safe database connection pooling configured

## Caching Strategy

**Cache Store:**
- Solid Cache (database-backed) - Uses PostgreSQL or SQLite
- Production: Database-backed (persistent, cluster-safe)
- Development/Test: Database-backed
- Max size: 256 MB (configurable)
- Namespace: Environment-based isolation (development/test/production)

**Cache Usage:**
- Rate limiter state storage (Rack::Attack)
- Rails cache for conventional caching needs
- Configured in `config/cache.yml`

## Background Job Processing

**Job Queue:**
- Solid Queue - Database-backed job processor (no external Redis required)
- Dispatcher: Polling interval 1 second, batch size 500
- Workers: 
  - 3 threads per process
  - Number of processes: Configurable via `JOB_CONCURRENCY` (default: 1)
  - Polling interval: 0.1 seconds
- All queues processed by default
- Configured in `config/queue.yml`

## Real-Time Communication

**Action Cable:**
- Adapter:
  - Development: Async (in-process only)
  - Test: Test adapter
  - Production: Solid Cable (database-backed, cluster-safe)
- Polling interval: 0.1 seconds
- Message retention: 1 day (production)
- Channel subscriptions: Database-backed subscription state
- Configured in `config/cable.yml`

## File Storage

**Media Storage:**
- Active Storage (Rails convention)
- Local Development: `storage/` directory
- Local Test: `tmp/storage/` directory
- Production: Configured via `config/storage.yml`
  - Current: Local filesystem
  - Available (commented): AWS S3, Google Cloud Storage, Azure Blob
- Image processing: Via `image_processing` gem (ImageMagick/libvips)

---

*Stack analysis: 2026-05-14*
