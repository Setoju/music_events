class AddLastWeatherFetchToBookings < ActiveRecord::Migration[8.1]
  def change
    add_column :bookings, :last_weather_fetch_at, :datetime
    add_index :bookings, :last_weather_fetch_at
  end
end
