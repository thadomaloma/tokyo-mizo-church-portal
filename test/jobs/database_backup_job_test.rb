require "test_helper"

class DatabaseBackupJobTest < ActiveJob::TestCase
  include EnvHelper

  PASSPHRASE = "a long passphrase".freeze
  # Wednesday and Sunday nights long after the fixtures were loaded, so
  # nothing counts as changed "today" unless a test changes it.
  QUIET_WEDNESDAY = Time.zone.local(2030, 1, 2, 23, 0)
  SUNDAY = Time.zone.local(2030, 1, 6, 23, 0)

  setup do
    @r2 = FakeR2.new
    @previous_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    @r2.stop
    Rails.cache = @previous_cache
  end

  test "uploads an encrypted backup on a day the finances changed" do
    travel_to QUIET_WEDNESDAY do
      record_an_expense
      run_backup
    end

    upload = @r2.requests.sole
    assert_equal "/tmc-backups/tmc-backup-2030-01-02-2300.sqlite3.gz.enc", upload[:path]
    restored = DatabaseBackup.decrypt(upload[:body], passphrase: PASSPHRASE)
    assert restored.start_with?("SQLite format 3")

    last = DatabaseBackup.last_upload
    assert_equal "tmc-backup-2030-01-02-2300.sqlite3.gz.enc", last["filename"]
    assert_equal upload[:body].bytesize, last["bytes"]
  end

  test "uploads nothing on a quiet weekday" do
    travel_to(QUIET_WEDNESDAY) { run_backup }

    assert_empty @r2.requests
  end

  test "a deleted transaction counts as a change" do
    transaction = travel_to(QUIET_WEDNESDAY - 3.days) { record_an_expense }

    travel_to QUIET_WEDNESDAY do
      transaction.destroy!
      run_backup
    end

    assert_equal 1, @r2.requests.size
  end

  test "always uploads on Sunday so there is a weekly copy" do
    travel_to(SUNDAY) { run_backup }

    assert_equal 1, @r2.requests.size
  end

  test "Send backup now uploads even on a quiet day" do
    travel_to(QUIET_WEDNESDAY) { run_backup(force: true) }

    assert_equal 1, @r2.requests.size
  end

  test "uploads nothing until a passphrase is set" do
    with_env(@r2.env.merge("BACKUP_PASSPHRASE" => nil)) do
      travel_to(SUNDAY) { DatabaseBackupJob.perform_now(force: true) }
    end

    assert_empty @r2.requests
    assert_nil DatabaseBackup.last_upload
  end

  test "runs every night at 11pm in production" do
    schedule = Rails.application.config_for(:recurring, env: "production").fetch(:nightly_database_backup)

    assert_equal "DatabaseBackupJob", schedule[:class]
    assert_equal "every day at 11pm Asia/Tokyo", schedule[:schedule]
  end

  private

  def run_backup(force: false)
    with_env(@r2.env.merge("BACKUP_PASSPHRASE" => PASSPHRASE)) { DatabaseBackupJob.perform_now(force: force) }
  end

  def record_an_expense
    FinanceTransaction.create!(
      transaction_type: "expense",
      finance_category: FinanceCategory.create!(name: "Backup test #{SecureRandom.hex(3)}", category_type: "expense"),
      recorded_by: users(:one),
      amount: 1_000,
      transaction_date: Date.current,
      payment_location: "cash"
    )
  end
end
