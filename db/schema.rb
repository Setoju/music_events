# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_15_124500) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "artists", force: :cascade do |t|
    t.text "bio"
    t.string "country"
    t.datetime "created_at", null: false
    t.string "genre"
    t.string "name"
    t.datetime "updated_at", null: false
    t.string "website"
    t.index ["genre"], name: "index_artists_on_genre"
  end

  create_table "bookings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "last_weather_fetch_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_bookings_on_event_id"
    t.index ["last_weather_fetch_at"], name: "index_bookings_on_last_weather_fetch_at"
    t.index ["user_id", "event_id"], name: "index_bookings_on_user_id_and_event_id_unique", unique: true
    t.index ["user_id"], name: "index_bookings_on_user_id"
  end

  create_table "event_artists", force: :cascade do |t|
    t.bigint "artist_id", null: false
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_event_artists_on_artist_id"
    t.index ["event_id", "artist_id"], name: "index_event_artists_on_event_id_and_artist_id", unique: true
    t.index ["event_id"], name: "index_event_artists_on_event_id"
  end

  create_table "event_contexts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "expires_at"
    t.datetime "parking_fetched_at"
    t.jsonb "parking_info", default: {}, null: false
    t.string "parking_status", default: "not_fetched", null: false
    t.datetime "updated_at", null: false
    t.jsonb "weather_data", default: {}, null: false
    t.text "weather_error"
    t.string "weather_error_code"
    t.datetime "weather_fetched_at"
    t.string "weather_status", default: "pending", null: false
    t.index ["event_id"], name: "index_event_contexts_on_event_id", unique: true
    t.index ["weather_error_code"], name: "index_event_contexts_on_weather_error_code"
    t.index ["weather_status"], name: "index_event_contexts_on_weather_status"
  end

  create_table "events", force: :cascade do |t|
    t.string "city"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "genre"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "name"
    t.datetime "starts_at"
    t.decimal "ticket_price"
    t.integer "tickets_capacity", default: 100, null: false
    t.datetime "updated_at", null: false
    t.string "venue"
    t.index ["city"], name: "index_events_on_city"
    t.index ["genre"], name: "index_events_on_genre"
    t.index ["starts_at"], name: "index_events_on_starts_at"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.integer "rating", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_reviews_on_event_id"
    t.index ["rating"], name: "index_reviews_on_rating"
    t.index ["user_id", "event_id"], name: "index_reviews_on_user_id_and_event_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
    t.check_constraint "rating >= 1 AND rating <= 5", name: "reviews_rating_between_1_and_5"
  end

  create_table "revoked_jwt_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "exp", null: false
    t.string "jti", null: false
    t.datetime "updated_at", null: false
    t.index ["exp"], name: "index_revoked_jwt_tokens_on_exp"
    t.index ["jti"], name: "index_revoked_jwt_tokens_on_jti", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "bookings", "events"
  add_foreign_key "bookings", "users"
  add_foreign_key "event_artists", "artists"
  add_foreign_key "event_artists", "events"
  add_foreign_key "event_contexts", "events"
  add_foreign_key "reviews", "events"
  add_foreign_key "reviews", "users"
end
