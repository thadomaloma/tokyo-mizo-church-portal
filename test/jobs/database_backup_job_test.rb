require "test_helper"

class DatabaseBackupJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  # Wednesday and Sunday nights long after the fixtures were loaded, so
  # nothing counts as changed "today" unless a test changes it.
  QUIET_WEDNESDAY = Time.zone.local(2030, 1, 2, 23, 0)
  SUNDAY = Time.zone.local(2030, 1, 6, 23, 0)

  setup do
    @previous_env = %w[BACKUP_PASSPHRASE BACKUP_EMAIL].index_with { |key| ENV[key] }
    ENV["BACKUP_PASSPHRASE"] = "a long passphrase"
    ENV["BACKUP_EMAIL"] = "backups@example.com"
  end

  teardown { @previous_env.each { |key, value| ENV[key] = value } }

  test "emails an encrypted backup on a day the finances changed" do
    travel_to QUIET_WEDNESDAY do
      record_an_expense
      assert_emails(1) { DatabaseBackupJob.perform_now }
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "backups@example.com" ], mail.to
    assert_match "Tokyo Mizo Church Finance backup", mail.subject
    attachment = mail.attachments.first
    assert_equal "tmc-backup-2030-01-02.sqlite3.gz.enc", attachment.filename
    assert attachment.body.decoded.b.start_with?(DatabaseBackup::MAGIC)
    assert_match "openssl enc -d", mail.body.encoded
  end

  test "sends nothing on a quiet weekday" do
    travel_to QUIET_WEDNESDAY do
      assert_no_emails { DatabaseBackupJob.perform_now }
    end
  end

  test "a deleted transaction counts as a change" do
    transaction = travel_to(QUIET_WEDNESDAY - 3.days) { record_an_expense }

    travel_to QUIET_WEDNESDAY do
      transaction.destroy!
      assert_emails(1) { DatabaseBackupJob.perform_now }
    end
  end

  test "always sends on Sunday so there is a weekly copy" do
    travel_to SUNDAY do
      assert_emails(1) { DatabaseBackupJob.perform_now }
    end
  end

  test "Send backup now sends even on a quiet day" do
    travel_to QUIET_WEDNESDAY do
      assert_emails(1) { DatabaseBackupJob.perform_now(force: true) }
    end
  end

  test "sends nothing until a passphrase is set" do
    ENV["BACKUP_PASSPHRASE"] = nil

    travel_to SUNDAY do
      assert_no_emails { DatabaseBackupJob.perform_now(force: true) }
    end
  end

  test "runs every night at 11pm in production" do
    schedule = Rails.application.config_for(:recurring, env: "production").fetch(:nightly_database_backup)

    assert_equal "DatabaseBackupJob", schedule[:class]
    assert_equal "every day at 11pm Asia/Tokyo", schedule[:schedule]
  end

  private

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
