class CreateEventContexts < ActiveRecord::Migration[8.0]
  def change
    create_table :event_contexts do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.jsonb :weather_data, null: false, default: {}
      t.string :weather_status, null: false, default: "pending"
      t.text :weather_error
      t.datetime :weather_fetched_at
      t.datetime :expires_at
      t.jsonb :parking_info, null: false, default: {}
      t.string :parking_status, null: false, default: "not_fetched"
      t.datetime :parking_fetched_at

      t.timestamps
    end

    add_index :event_contexts, :weather_status
  end
end
