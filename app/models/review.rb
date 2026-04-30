class Review < ApplicationRecord
  RATING_RANGE = 1..5

  belongs_to :user
  belongs_to :event

  validates :rating, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: RATING_RANGE.begin, less_than_or_equal_to: RATING_RANGE.end }
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
