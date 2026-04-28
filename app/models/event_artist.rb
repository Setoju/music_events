class EventArtist < ApplicationRecord
  belongs_to :event
  belongs_to :artist

  validates :event_id, presence: true
  validates :artist_id, presence: true
end
