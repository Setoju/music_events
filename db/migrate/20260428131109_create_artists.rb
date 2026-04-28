class CreateArtists < ActiveRecord::Migration[8.1]
  def change
    create_table :artists do |t|
      t.string :name
      t.string :genre
      t.text :bio
      t.string :country
      t.string :website, null: true

      t.timestamps
    end
  end
end
