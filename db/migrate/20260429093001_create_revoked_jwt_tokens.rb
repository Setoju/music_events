class CreateRevokedJwtTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :revoked_jwt_tokens do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false

      t.timestamps
    end

    add_index :revoked_jwt_tokens, :jti, unique: true
    add_index :revoked_jwt_tokens, :exp
  end
end
