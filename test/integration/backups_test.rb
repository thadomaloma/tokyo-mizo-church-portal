require "test_helper"

class BackupsTest < ActionDispatch::IntegrationTest
  include EnvHelper

  setup { @r2 = FakeR2.new }
  teardown { @r2.stop }

  test "Settings says when backups are off" do
    with_env(@r2.env.merge("BACKUP_PASSPHRASE" => nil)) do
      sign_in_as users(:one)
      get admin_settings_path
    end

    assert_select "[data-settings-backup]", text: /Backups are off/
    assert_select "[data-settings-backup] button", count: 0
  end

  test "an admin can send a backup now and sees when the last one ran" do
    previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    with_env(@r2.env.merge("BACKUP_PASSPHRASE" => "a long passphrase")) do
      sign_in_as users(:one)
      get admin_settings_path
      assert_select "[data-settings-backup]", text: /saved to Cloudflare R2 at 11pm/
      assert_select "[data-last-backup]", count: 0

      assert_enqueued_with(job: DatabaseBackupJob, args: [ { force: true } ]) { post admin_backup_path }
      assert_redirected_to admin_settings_path
      assert_equal "Backup started. It will appear in Cloudflare R2 within a minute.", flash[:notice]

      perform_enqueued_jobs
      get admin_settings_path
      assert_select "[data-last-backup]", text: /Last backup: .+ · \d+(\.\d+)? KB/
    end
  ensure
    Rails.cache = previous_cache
  end

  test "only the Chairman or Secretary can send a backup" do
    with_env(@r2.env.merge("BACKUP_PASSPHRASE" => "a long passphrase")) do
      sign_in_as users(:three)
      assert_no_enqueued_jobs(only: DatabaseBackupJob) { post admin_backup_path }
    end

    assert_redirected_to admin_root_path
  end

  private

  def sign_in_as(user)
    post user_session_path, params: { user: { email: user.email, password: "password" } }
  end
end
