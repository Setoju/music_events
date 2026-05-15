class AddWeatherFetchAttemptsToBookings < ActiveRecord::Migration[7.0]
  def change
    add_column :bookings, :weather_fetch_attempts_count, :integer, default: 0, null: false
    add_column :bookings, :last_weather_fetch_attempt_at, :datetime
    add_index :bookings, :last_weather_fetch_attempt_at
  end
end
