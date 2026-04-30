class Event < ApplicationRecord
  has_many :event_artists, dependent: :destroy
  has_many :artists, through: :event_artists
  has_many :bookings, dependent: :destroy
  has_many :users, through: :bookings
  has_many :reviews, dependent: :destroy

  validates :name, presence: true
  validates :venue, presence: true
  validates :city, presence: true
  validates :starts_at, presence: true
  validates :ticket_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :tickets_capacity, numericality: { only_integer: true, greater_than: 0 }

  scope :upcoming, -> { where("starts_at >= ?", Time.current).order(:starts_at) }
  scope :past, -> { where("starts_at < ?", Time.current).order(starts_at: :desc) }
  scope :by_city, ->(city) { where(city: city) }
  scope :by_genre, ->(genre) { where(genre: genre) }

  def booked_tickets
    bookings.count
  end

  def remaining_tickets
    tickets_capacity - booked_tickets
  end

  def upcoming?
    starts_at.present? && starts_at >= Time.current
  end
end
