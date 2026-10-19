require "test_helper"

class BackupsTest < ActionDispatch::IntegrationTest
  test "Settings says when backups are off" do
    with_backup_env("BACKUP_PASSPHRASE" => nil) do
      sign_in_as users(:one)
      get admin_settings_path
    end

    assert_select "[data-settings-backup]", text: /Email backups are off/
    assert_select "[data-settings-backup] button", count: 0
  end

  test "an admin can send a backup now" do
    with_backup_env("BACKUP_PASSPHRASE" => "a long passphrase", "BACKUP_EMAIL" => "backups@example.com") do
      sign_in_as users(:one)
      get admin_settings_path
      assert_select "[data-settings-backup]", text: /emailed to backups@example.com at 11pm on days the finances change/

      assert_enqueued_with(job: DatabaseBackupJob, args: [ { force: true } ]) { post admin_backup_path }
    end

    assert_redirected_to admin_settings_path
    assert_equal "Backup is on its way to backups@example.com.", flash[:notice]
  end

  test "only the Chairman or Secretary can send a backup" do
    with_backup_env("BACKUP_PASSPHRASE" => "a long passphrase", "BACKUP_EMAIL" => "backups@example.com") do
      sign_in_as users(:three)
      assert_no_enqueued_jobs(only: DatabaseBackupJob) { post admin_backup_path }
    end

    assert_redirected_to admin_root_path
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end

  def with_backup_env(values)
    previous = values.keys.index_with { |key| ENV[key] }
    values.each { |key, value| ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| ENV[key] = value }
  end
end
