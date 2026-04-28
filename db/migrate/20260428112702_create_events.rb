class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :name
      t.string :venue
      t.string :city
      t.string :genre
      t.datetime :starts_at
      t.decimal :ticket_price
      t.text :description

      t.timestamps
    end
  end
end
