class AddPerformanceIndexes < ActiveRecord::Migration[8.1]
  def change
    # Query performance for upcoming/past event scopes
    add_index :events, :starts_at, if_not_exists: true

    # Filter by city and genre on events
    add_index :events, :city, if_not_exists: true
    add_index :events, :genre, if_not_exists: true

    # Filter artists by genre
    add_index :artists, :genre, if_not_exists: true

    # Analytics and sorting on reviews
    add_index :reviews, :rating, if_not_exists: true

    # Query by artist on event_artists (already has individual indexes, but good for reference)
    # Composite index for finding artists by event efficiently
    add_index :event_artists, [ :event_id, :artist_id ], unique: true, if_not_exists: true
  end
end
