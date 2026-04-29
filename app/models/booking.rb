class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :event

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validate :event_must_be_upcoming
  validate :enough_tickets_available
  validates :user_id, uniqueness: { scope: :event_id }

  def self.create_for!(user:, event:, quantity:)
    booking = new(user: user, event: event, quantity: quantity)

    transaction do
      event.with_lock do
        booking.save!
      end
    end

    booking
  end

  private

  def event_must_be_upcoming
    return if event.blank? || event.upcoming?

    errors.add(:event, "has already started")
  end

  def enough_tickets_available
    return if event.blank? || quantity.blank?

    booked_without_self = event.bookings.where.not(id: id).sum(:quantity)
    remaining_capacity = event.tickets_capacity - booked_without_self
    return if quantity <= remaining_capacity

    errors.add(:base, "No more tickets available")
  end
end
