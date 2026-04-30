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

ActiveRecord::Schema[8.1].define(version: 2026_04_30_110100) do
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
  end

  create_table "bookings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_bookings_on_event_id"
    t.index ["user_id", "event_id"], name: "index_bookings_on_user_id_and_event_id", unique: true
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

  create_table "events", force: :cascade do |t|
    t.string "city"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "genre"
    t.string "name"
    t.datetime "starts_at"
    t.decimal "ticket_price"
    t.integer "tickets_capacity", default: 100, null: false
    t.datetime "updated_at", null: false
    t.string "venue"
  end

  create_table "reviews", force: :cascade do |t|
    t.text "comment"
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.integer "rating", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_id"], name: "index_reviews_on_event_id"
    t.index ["user_id", "event_id"], name: "index_reviews_on_user_id_and_event_id", unique: true
    t.index ["user_id"], name: "index_reviews_on_user_id"
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
  add_foreign_key "reviews", "events"
  add_foreign_key "reviews", "users"
end
