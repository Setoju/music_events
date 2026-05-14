class Artist < ApplicationRecord
  has_many :event_artists, dependent: :destroy
  has_many :events, through: :event_artists

  validates :name, presence: true
  validates :bio, presence: true, length: { minimum: 10, maximum: 2000 }
  validates :genre, presence: true
  validates :country, presence: true
  validates :website, format: URI.regexp(%w[http https])

  scope :by_genre, ->(genre) { where(genre: genre) }
  scope :by_country, ->(country) { where(country: country) }
end
