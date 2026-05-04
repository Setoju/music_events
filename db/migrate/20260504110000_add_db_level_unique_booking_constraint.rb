class AddDbLevelUniqueBookingConstraint < ActiveRecord::Migration[8.1]
  INDEX_NAME = "index_bookings_on_user_id_and_event_id_unique"

  def up
    return if index_exists?(:bookings, [ :user_id, :event_id ], unique: true)

    add_index :bookings, [ :user_id, :event_id ], unique: true, name: INDEX_NAME
  end

  def down
    remove_index :bookings, name: INDEX_NAME, if_exists: true
  end
end
