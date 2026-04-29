class Review < ApplicationRecord
  enum :rating, {
    could_be_better: 0,
    good: 1,
    great: 2,
    perfect: 3
  }

  belongs_to :user
  belongs_to :event

  validates :rating, presence: true
  validates :user_id, uniqueness: { scope: :event_id, message: "has already reviewed this event" }
  validate :user_must_have_booking
  validate :event_must_have_started

  private

  def user_must_have_booking
    return if user.blank? || event.blank?
    return if Booking.exists?(user_id: user.id, event_id: event.id)

    errors.add(:base, "Only users with bookings can review this event")
  end

  def event_must_have_started
    return if event.blank? || event.starts_at.blank?
    return if event.starts_at <= Time.current

    errors.add(:base, "Review can be created only after the event starts")
  end
end
