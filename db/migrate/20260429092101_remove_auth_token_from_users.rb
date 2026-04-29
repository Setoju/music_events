class RemoveAuthTokenFromUsers < ActiveRecord::Migration[8.1]
  def change
    remove_index :users, :auth_token if index_exists?(:users, :auth_token)
    remove_column :users, :auth_token, :string if column_exists?(:users, :auth_token)
  end
end
