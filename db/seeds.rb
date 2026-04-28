puts "🧹 Cleaning database..."
EventArtist.destroy_all
Event.destroy_all
Artist.destroy_all

# ─────────────────────────────────────────
# ARTISTS
# ─────────────────────────────────────────
puts "🎤 Seeding artists..."

artists = Artist.create!([
  {
    name: "Kalush Orchestra",
    genre: "Hip-Hop / Folk",
    bio: "Ukrainian hip-hop group blending modern rap with traditional Hutsul folk music. Eurovision 2022 winners who brought Ukrainian culture to a global stage.",
    country: "Ukraine",
    website: "https://kaluschorchestra.com"
  },
  {
    name: "Dakh Daughters",
    genre: "Experimental",
    bio: "An avant-garde Freak Cabaret band from Kyiv blending theater, poetry, punk, and folk into hauntingly powerful live performances.",
    country: "Ukraine",
    website: "https://dakhdaughters.com"
  },
  {
    name: "Go_A",
    genre: "Electronic",
    bio: "Ukrainian electronic duo known for fusing techno beats with authentic Ukrainian folk melodies and traditional instruments.",
    country: "Ukraine",
    website: "https://go-a.com.ua"
  },
  {
    name: "ONUKA",
    genre: "Electronic",
    bio: "Kyiv-based electronic artist Nata Zhyzhchenko creates ethereal soundscapes merging synthesizers with ancient Ukrainian instruments like the trembita and sopilka.",
    country: "Ukraine",
    website: "https://onuka.com.ua"
  },
  {
    name: "DakhaBrakha",
    genre: "Folk",
    bio: "World-music quartet from Kyiv performing an explosive mix of Ukrainian folk with elements of African, Arabic, and Australian music. One of Ukraine's most internationally acclaimed acts.",
    country: "Ukraine",
    website: "https://dakhabrakha.com.ua"
  },
  {
    name: "Okean Elzy",
    genre: "Rock",
    bio: "Legendary Ukrainian rock band led by Svyatoslav Vakarchuk, with over 30 years of anthemic rock that has shaped an entire generation of Ukrainian music lovers.",
    country: "Ukraine",
    website: "https://okeanelzy.com"
  },
  {
    name: "Jinjer",
    genre: "Metal",
    bio: "Internationally acclaimed metal band from Donetsk, Ukraine. Known for vocalist Tatiana Shmailyuk's seamless switch between melodic singing and aggressive growling.",
    country: "Ukraine",
    website: "https://jinjer-metal.com"
  },
  {
    name: "The Hardkiss",
    genre: "Pop / Rock",
    bio: "Stylish and powerful Kyiv-based rock trio fronted by Julia Sanina. Mixing polished pop production with rock energy and deeply emotional songwriting.",
    country: "Ukraine",
    website: "https://thehardkiss.com"
  },
  {
    name: "Skryabin",
    genre: "Pop / Electronic",
    bio: "Iconic Ukrainian pop-rock band founded by the late Andriy Kuzmenko, whose witty lyrics and catchy melodies made them one of the most beloved acts in Ukrainian music history.",
    country: "Ukraine",
    website: "https://skryabin.ua"
  },
  {
    name: "Haydamaky",
    genre: "Folk / Punk",
    bio: "High-energy Kyiv band combining Ukrainian folk traditions with punk rock, ska, and reggae. Famous for their electrifying live performances and politically charged lyrics.",
    country: "Ukraine",
    website: "https://haydamaky.com"
  }
])

puts "✅ #{artists.count} artists created"

# ─────────────────────────────────────────
# EVENTS
# ─────────────────────────────────────────
puts "🎶 Seeding events..."

events = Event.create!([
  {
    name: "Kyiv Electronic Nights",
    venue: "Closer",
    city: "Kyiv",
    genre: "Electronic",
    starts_at: 3.days.from_now,
    ticket_price: 350,
    description: "An immersive night of cutting-edge Ukrainian electronic music deep inside Kyiv's most iconic underground venue."
  },
  {
    name: "Folk Roots Festival",
    venue: "Mystetskyi Arsenal",
    city: "Kyiv",
    genre: "Folk",
    starts_at: 1.week.from_now,
    ticket_price: 450,
    description: "A celebration of Ukrainian roots music featuring both established names and emerging folk artists across two stages."
  },
  {
    name: "Lviv Jazz Weekend",
    venue: "Dzyga Art Club",
    city: "Lviv",
    genre: "Jazz",
    starts_at: 5.days.from_now,
    ticket_price: 300,
    description: "Three nights of world-class jazz in the heart of Lviv's cobblestone old town. Intimate venue, outstanding acoustics."
  },
  {
    name: "Metal Assault Fest",
    venue: "Bingo Concert Hall",
    city: "Kyiv",
    genre: "Metal",
    starts_at: 2.weeks.from_now,
    ticket_price: 600,
    description: "Ukraine's heaviest metal showcase with multiple stages, merch market, and after-parties. Not for the faint-hearted."
  },
  {
    name: "Rock Under the Stars",
    venue: "Atlas Weekend Stage",
    city: "Kyiv",
    genre: "Rock",
    starts_at: 10.days.from_now,
    ticket_price: 550,
    description: "An open-air rock extravaganza with Ukraine's biggest rock acts performing under the summer sky at the VDNH park."
  },
  {
    name: "Odesa Beach Beats",
    venue: "Ibiza Beach Club",
    city: "Odesa",
    genre: "Electronic",
    starts_at: 4.days.from_now,
    ticket_price: 400,
    description: "Sunset DJ sets and live electronic acts right on the Black Sea shore. Dancing starts at dusk and ends at dawn."
  },
  {
    name: "Experimental Sound Lab",
    venue: "Izone Creative Space",
    city: "Kyiv",
    genre: "Experimental",
    starts_at: 6.days.from_now,
    ticket_price: 250,
    description: "A boundary-pushing showcase of Ukraine's most avant-garde and experimental artists. Expect the unexpected."
  },
  {
    name: "Kharkiv Rock Revival",
    venue: "FreeDOM Stage",
    city: "Kharkiv",
    genre: "Rock",
    starts_at: 3.weeks.from_now,
    ticket_price: 480,
    description: "Kharkiv's biggest rock gathering, celebrating the resilience and creative spirit of eastern Ukraine's music scene."
  },
  {
    name: "Acoustic Winter Evening",
    venue: "Palats Ukraina",
    city: "Kyiv",
    genre: "Folk",
    starts_at: 1.month.from_now,
    ticket_price: 700,
    description: "An intimate acoustic evening in Kyiv's grandest concert hall — expect stripped-back performances and emotional storytelling."
  },
  {
    name: "Dnipro Punk Fiesta",
    venue: "Live Stage Club",
    city: "Dnipro",
    genre: "Folk / Punk",
    starts_at: 2.weeks.from_now,
    ticket_price: 200,
    description: "A rowdy, high-energy punk celebration on the banks of the Dnipro river. Crowd-surfing strongly encouraged."
  }
])

puts "✅ #{events.count} events created"

# ─────────────────────────────────────────
# EVENT <-> ARTIST ASSOCIATIONS
# ─────────────────────────────────────────
puts "🔗 Linking artists to events..."

event_by_name   = ->(name)  { events.find   { |e| e.name == name } }
artist_by_name  = ->(name)  { artists.find  { |a| a.name == name } }

links = [
  [ "Kyiv Electronic Nights",    [ "Go_A", "ONUKA" ] ],
  [ "Folk Roots Festival",       [ "DakhaBrakha", "Haydamaky", "Dakh Daughters" ] ],
  [ "Lviv Jazz Weekend",         [ "ONUKA" ] ],
  [ "Metal Assault Fest",        [ "Jinjer", "Haydamaky" ] ],
  [ "Rock Under the Stars",      [ "Okean Elzy", "The Hardkiss", "Skryabin" ] ],
  [ "Odesa Beach Beats",         [ "Go_A", "ONUKA" ] ],
  [ "Experimental Sound Lab",    [ "Dakh Daughters", "Kalush Orchestra" ] ],
  [ "Kharkiv Rock Revival",      [ "Jinjer", "Okean Elzy", "The Hardkiss" ] ],
  [ "Acoustic Winter Evening",   [ "DakhaBrakha", "Dakh Daughters" ] ],
  [ "Dnipro Punk Fiesta",        [ "Haydamaky", "Kalush Orchestra" ] ]
]

links.each do |event_name, artist_names|
  ev = event_by_name.call(event_name)
  artist_names.each do |artist_name|
    ar = artist_by_name.call(artist_name)
    EventArtist.create!(event: ev, artist: ar)
  end
end

puts "✅ #{EventArtist.count} artist-event links created"
puts ""
puts "🎸 Seed complete!"
puts "   Artists : #{Artist.count}"
puts "   Events  : #{Event.count}"
puts "   Links   : #{EventArtist.count}"
