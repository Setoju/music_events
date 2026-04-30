# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Clearing existing data..."
Booking.destroy_all
Review.destroy_all
EventArtist.destroy_all
Event.destroy_all
Artist.destroy_all
User.destroy_all
RevokedJwtToken.destroy_all
puts "Data cleared."

# ---------------------------------------------------------------------------
# Users
# ---------------------------------------------------------------------------
puts "Creating users..."

User.create!(
  email: "admin@example.com",
  password: "password",
  password_confirmation: "password",
  role: :admin
)

user1 = User.create!(email: "user1@example.com", password: "password", password_confirmation: "password", role: :user)
user2 = User.create!(email: "user2@example.com", password: "password", password_confirmation: "password", role: :user)
user3 = User.create!(email: "user3@example.com", password: "password", password_confirmation: "password", role: :user)

puts "  #{User.count} users created."

# ---------------------------------------------------------------------------
# Artists
# ---------------------------------------------------------------------------
puts "Creating artists..."

rockers = Artist.create!(
  name: "The Rockers",
  genre: "Rock",
  bio: "A legendary rock band known for their explosive energy and sold-out arena tours.",
  country: "USA",
  website: "https://therockers.com"
)

jazz_collective = Artist.create!(
  name: "Jazz Fusion Collective",
  genre: "Jazz",
  bio: "Blending traditional European jazz with contemporary electronic textures.",
  country: "France",
  website: "https://jazzfusion.com"
)

pop_sensations = Artist.create!(
  name: "Pop Sensations",
  genre: "Pop",
  bio: "Chart-topping pop artists with catchy tunes and dazzling stage productions.",
  country: "UK",
  website: "https://popsensations.com"
)

indie_bloom = Artist.create!(
  name: "Indie Bloom",
  genre: "Indie",
  bio: "An emerging indie act celebrated for heartfelt lyrics and dreamy guitar work.",
  country: "Ukraine",
  website: "https://indiebloom.ua"
)

electronic_pulse = Artist.create!(
  name: "Electronic Pulse",
  genre: "Electronic",
  bio: "A DJ duo pushing the boundaries of techno and ambient electronica.",
  country: "Germany",
  website: "https://electronicpulse.de"
)

puts "  #{Artist.count} artists created."

# ---------------------------------------------------------------------------
# Events — future (bookable)
# ---------------------------------------------------------------------------
puts "Creating upcoming events..."

rock_fest = Event.create!(
  name: "Rock Fest 2026",
  venue: "Arena Stage",
  city: "Kyiv",
  genre: "Rock",
  starts_at: 1.week.from_now,
  ticket_price: 50.00,
  tickets_capacity: 100,
  description: "The biggest rock festival of the year — three stages, twelve bands, one unforgettable night."
)

jazz_night = Event.create!(
  name: "Summer Jazz Night",
  venue: "City Hall",
  city: "Lviv",
  genre: "Jazz",
  starts_at: 2.weeks.from_now,
  ticket_price: 75.00,
  tickets_capacity: 50,
  description: "An intimate evening of soulful jazz in the heart of Lviv's historic City Hall."
)

pop_extravaganza = Event.create!(
  name: "Pop Extravaganza",
  venue: "Olympic Stadium",
  city: "Kyiv",
  genre: "Pop",
  starts_at: 3.weeks.from_now,
  ticket_price: 60.00,
  tickets_capacity: 200,
  description: "Experience the biggest pop hits live under one roof."
)

electronic_rave = Event.create!(
  name: "Electric Nights",
  venue: "Closer Club",
  city: "Kyiv",
  genre: "Electronic",
  starts_at: 10.days.from_now,
  ticket_price: 35.00,
  tickets_capacity: 150,
  description: "An all-night electronic music experience featuring cutting-edge visuals and sound."
)

# ---------------------------------------------------------------------------
# Events — past (reviewable)
# ---------------------------------------------------------------------------
puts "Creating past events..."

indie_showcase = Event.create!(
  name: "Indie Showcase",
  venue: "Small Venue",
  city: "Kyiv",
  genre: "Indie",
  starts_at: 1.week.ago,
  ticket_price: 25.00,
  tickets_capacity: 30,
  description: "A cosy evening spotlighting the best emerging indie talent in Ukraine."
)

jazz_classics = Event.create!(
  name: "Jazz Classics Evening",
  venue: "Philharmonic Hall",
  city: "Odesa",
  genre: "Jazz",
  starts_at: 3.weeks.ago,
  ticket_price: 80.00,
  tickets_capacity: 120,
  description: "A tribute to the golden age of jazz — timeless standards performed with modern flair."
)

rock_throwback = Event.create!(
  name: "Rock Throwback Night",
  venue: "Stadium",
  city: "Kharkiv",
  genre: "Rock",
  starts_at: 2.months.ago,
  ticket_price: 45.00,
  tickets_capacity: 80,
  description: "All the classic rock anthems you grew up with, played live."
)

puts "  #{Event.count} events created (#{Event.where('starts_at > ?', Time.current).count} upcoming, #{Event.where('starts_at <= ?', Time.current).count} past)."

# ---------------------------------------------------------------------------
# Event ↔ Artist assignments
# ---------------------------------------------------------------------------
puts "Assigning artists to events..."

EventArtist.create!(event: rock_fest,         artist: rockers)
EventArtist.create!(event: rock_fest,         artist: pop_sensations)   # co-headliner
EventArtist.create!(event: jazz_night,        artist: jazz_collective)
EventArtist.create!(event: pop_extravaganza,  artist: pop_sensations)
EventArtist.create!(event: electronic_rave,   artist: electronic_pulse)
EventArtist.create!(event: indie_showcase,    artist: indie_bloom)
EventArtist.create!(event: indie_showcase,    artist: rockers)           # surprise guest
EventArtist.create!(event: jazz_classics,     artist: jazz_collective)
EventArtist.create!(event: rock_throwback,    artist: rockers)

puts "  #{EventArtist.count} artist–event links created."

# ---------------------------------------------------------------------------
# Bookings
# ---------------------------------------------------------------------------
puts "Creating bookings..."

# Upcoming events
Booking.create_for!(user: user1, event: rock_fest)
Booking.create_for!(user: user2, event: jazz_night)
Booking.create_for!(user: user3, event: pop_extravaganza)
Booking.create_for!(user: user1, event: electronic_rave)
Booking.create_for!(user: user3, event: rock_fest)

# Past events — bypass the "event has already started" validation so we can
# backfill historical bookings that reviews depend on.
[
  { user: user1, event: indie_showcase },
  { user: user2, event: indie_showcase },
  { user: user3, event: indie_showcase },
  { user: user1, event: jazz_classics },
  { user: user2, event: jazz_classics },
  { user: user1, event: rock_throwback },
  { user: user3, event: rock_throwback }
].each do |attrs|
  booking = Booking.new(attrs)
  booking.save!(validate: false)
end

puts "  #{Booking.count} bookings created."

# ---------------------------------------------------------------------------
# Reviews  (only on past events, only from users who booked)
# ---------------------------------------------------------------------------
puts "Creating reviews..."

# Indie Showcase — 3 reviews
Review.create!(user: user1, event: indie_showcase, rating: :perfect, comment: "Absolutely loved the indie vibe! Indie Bloom were phenomenal — genuinely one of the best gigs I've attended.")
Review.create!(user: user2, event: indie_showcase, rating: :good,    comment: "Really solid show. The sound quality in the second half was great; first half felt a bit muddy.")
Review.create!(user: user3, event: indie_showcase, rating: :perfect, comment: "What a surprise set from The Rockers at the end. The whole crowd went wild. Will definitely be back next year.")

# Jazz Classics Evening — 2 reviews
Review.create!(user: user1, event: jazz_classics, rating: :perfect, comment: "Philharmonic Hall is the perfect venue for jazz. The acoustics are extraordinary and the setlist was impeccable.")
Review.create!(user: user2, event: jazz_classics, rating: :good,    comment: "Beautiful evening overall. A couple of the arrangements felt overly safe, but the musicianship was top-tier.")

# Rock Throwback Night — 2 reviews
Review.create!(user: user1, event: rock_throwback, rating: :good,    comment: "Classic setlist and a lively crowd. Stadium could use better sound mixing but the energy more than made up for it.")
Review.create!(user: user3, event: rock_throwback, rating: :perfect, comment: "Hearing those anthems live brought back so many memories. The Rockers still have it after all these years.")

puts "  #{Review.count} reviews created."

puts ""
puts "Seed data created successfully!"
puts "  Users:        #{User.count}"
puts "  Artists:      #{Artist.count}"
puts "  Events:       #{Event.count}"
puts "  Bookings:     #{Booking.count}"
puts "  Reviews:      #{Review.count}"
