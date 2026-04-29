class AddTicketsCapacityToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :tickets_capacity, :integer, null: false, default: 100
  end
end
