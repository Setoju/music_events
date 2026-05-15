class EventContext < ApplicationRecord
  belongs_to :event

  scope :weather_pending, -> { where(weather_status: "pending") }
  scope :weather_failed, -> { where(weather_status: "failed") }

  validates :event_id, presence: true, uniqueness: true

  def weather_fresh?
    expires_at.present? && expires_at > Time.current
  end

  def weather_available?
    weather_status == "success" && weather_data.present?
  end

  def weather_error_code
    return nil unless weather_status == 'failed'

    return self[:weather_error_code] if self[:weather_error_code].present?

    WeatherErrorMapper.map(weather_error)
  end
end