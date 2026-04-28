class Event < ApplicationRecord
  validates :name, presence: true
  validates :venue, presence: true
  validates :city, presence: true
  validates :starts_at, presence: true
  validates :ticket_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :upcoming, -> { where("starts_at >= ?", Time.current).order(:starts_at) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_genre, ->(genre) { where(genre: genre) }
end
