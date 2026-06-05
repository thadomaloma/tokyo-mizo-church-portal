class ResetUserRolesInUsers < ActiveRecord::Migration[8.1]
  def up
    change_column_default :users, :role, nil

    User.reset_column_information
    User.update_all(role: nil)

    change_column_default :users, :role, 7
  end

  def down
    change_column_default :users, :role, nil
  end
end
