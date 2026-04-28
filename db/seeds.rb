Event.create!([
  { name: "Jazz Night", venue: "Blue Note", city: "Kyiv", genre: "Jazz",
    starts_at: 2.days.from_now, ticket_price: 350 },
  { name: "Metal Fest", venue: "Arena", city: "Lviv", genre: "Metal",
    starts_at: 1.week.from_now, ticket_price: 500 },
  { name: "Indie Vibes", venue: "Closer", city: "Kyiv", genre: "Indie",
    starts_at: 3.days.from_now, ticket_price: 200 }
])
