class RemoveQuantityFieldFromBookings < ActiveRecord::Migration[8.1]
  def change
    remove_column :bookings, :quantity, :integer, default: 1, null: false
  end
end
