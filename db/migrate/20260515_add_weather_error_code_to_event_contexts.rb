class AddWeatherErrorCodeToEventContexts < ActiveRecord::Migration[8.1]
  def change
    add_column :event_contexts, :weather_error_code, :string
    add_index :event_contexts, :weather_error_code
  end
end
