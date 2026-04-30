# Music Events API

## Setup

```bash
bundle install
bundle exec rails db:migrate
bundle exec rails s
```

## Authentication (JWT Bearer Token)

1. Sign up: `POST /api/v1/auth/sign_up`
2. Sign in: `POST /api/v1/auth/sign_in`
3. Logout (revoke current token): `DELETE /api/v1/auth/logout`
4. Use returned JWT in headers:

```http
Authorization: Bearer <token>
```

Protected endpoint example: `GET /api/v1/auth/me`

JWT is validated server-side and revoked tokens are stored in denylist.

## Roles and permissions (Pundit)

- **Admin**: create/update/delete events and artists.
- **User**: book tickets, list own bookings, create/list reviews (subject to booking/event rules).
- **Guest**: can only read events and artists.

## Booking

- Create booking: `POST /api/v1/events/:event_id/bookings`
- List current user bookings: `GET /api/v1/bookings`

Booking rules:
- Event must be upcoming.
- Each booking reserves one ticket.
- Cannot exceed event `tickets_capacity`.

## Reviews

- Create review: `POST /api/v1/events/:event_id/reviews`
- List event reviews: `GET /api/v1/events/:event_id/reviews`

Review rules:
- User must have a booking for the event.
- Review can be created only after event start time.
- One review per user per event.
- Rating enum: `could_be_better`, `good`, `great`, `perfect`.

## Tests

```bash
bundle exec rspec
```
