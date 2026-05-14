class Booking < ApplicationRecord
  class DuplicateBooking < StandardError; end
  class NoTicketsAvailable < StandardError; end

  belongs_to :user
  belongs_to :event

  validate :event_must_be_upcoming
  validates :user_id, uniqueness: { scope: :event_id }

  def self.create_for!(user:, event:)
    transaction do
      event.with_lock do
        event.reload

        raise DuplicateBooking if user.bookings.exists?(event_id: event.id)
        raise NoTicketsAvailable if event.remaining_tickets <= 0

        booking = new(user: user, event: event)
        booking.save!
        booking
      end
    end
  end

  private

  def event_must_be_upcoming
    return if event.blank? || event.upcoming?

    errors.add(:event, "has already started")
  end
end
