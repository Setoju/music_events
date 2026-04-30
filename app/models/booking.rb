class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :event

  validate :event_must_be_upcoming
  validates :user_id, uniqueness: { scope: :event_id }

  def self.create_for!(user:, event:)
    booking = new(user: user, event: event)

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
end
