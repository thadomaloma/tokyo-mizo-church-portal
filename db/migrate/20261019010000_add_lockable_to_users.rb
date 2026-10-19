# Devise lockable: an account locks for an hour after 10 wrong passwords.
# Only adds columns, so existing rows are untouched.
class AddLockableToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :failed_attempts, :integer, default: 0, null: false
    add_column :users, :locked_at, :datetime
  end
end
