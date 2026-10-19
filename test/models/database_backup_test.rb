require "test_helper"
require "open3"

class DatabaseBackupTest < ActiveSupport::TestCase
  PASSPHRASE = "correct horse battery staple".freeze

  test "a backup decrypts to a copy of the database" do
    backup = DatabaseBackup.new(passphrase: PASSPHRASE, created_on: Date.new(2026, 10, 19))

    assert_equal "tmc-backup-2026-10-19.sqlite3.gz.enc", backup.filename
    assert backup.data.start_with?(DatabaseBackup::MAGIC)

    with_restored(DatabaseBackup.decrypt(backup.data, passphrase: PASSPHRASE)) do |db|
      assert_equal FinanceTransaction.count, db.get_first_value("SELECT COUNT(*) FROM finance_transactions")
      assert_equal FinanceTransaction.sum(:amount), db.get_first_value("SELECT SUM(amount) FROM finance_transactions")
    end
  end

  test "the wrong passphrase cannot open a backup" do
    backup = DatabaseBackup.new(passphrase: PASSPHRASE)

    assert_raises(OpenSSL::Cipher::CipherError, Zlib::Error) do
      DatabaseBackup.decrypt(backup.data, passphrase: "something else")
    end
  end

  test "backups are never made without a passphrase" do
    assert_raises(ArgumentError) { DatabaseBackup.new(passphrase: "") }
  end

  test "the openssl command line opens a backup without the app" do
    skip "openssl is not installed" unless system("openssl version", out: File::NULL, err: File::NULL)

    backup = DatabaseBackup.new(passphrase: PASSPHRASE)
    gzipped, status = Open3.capture2(
      "openssl", "enc", "-d", "-aes-256-cbc", "-pbkdf2", "-iter", DatabaseBackup::ITERATIONS.to_s, "-md", "sha256",
      "-pass", "pass:#{PASSPHRASE}", stdin_data: backup.data, binmode: true
    )

    assert status.success?
    with_restored(Zlib.gunzip(gzipped)) do |db|
      assert_equal FinanceTransaction.count, db.get_first_value("SELECT COUNT(*) FROM finance_transactions")
    end
  end

  private

  def with_restored(bytes)
    Dir.mktmpdir do |dir|
      path = File.join(dir, "restored.sqlite3")
      File.binwrite(path, bytes)
      db = SQLite3::Database.new(path)
      assert_equal "ok", db.get_first_value("PRAGMA integrity_check")
      yield db
    ensure
      db&.close
    end
  end
end
