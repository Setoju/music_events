class EnsureWeatherErrorCodeOnEventContexts < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:event_contexts, :weather_error_code)
      add_column :event_contexts, :weather_error_code, :string
    end

    unless index_exists?(:event_contexts, :weather_error_code)
      add_index :event_contexts, :weather_error_code
    end
  end

  def down
    if index_exists?(:event_contexts, :weather_error_code)
      remove_index :event_contexts, :weather_error_code
    end

    if column_exists?(:event_contexts, :weather_error_code)
      remove_column :event_contexts, :weather_error_code
    end
  end
end
