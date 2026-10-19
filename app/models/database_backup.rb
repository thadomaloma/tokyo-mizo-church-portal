require "zlib"

# A copy of the whole database (records, cache and jobs all live in one
# SQLite file), gzipped and encrypted with BACKUP_PASSPHRASE.
#
# The file is exactly what `openssl enc -aes-256-cbc -pbkdf2` writes, so a
# backup can be opened on any computer without this app:
#
#   openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \
#     -in tmc-backup-2026-10-19.sqlite3.gz.enc -out backup.sqlite3.gz
#   gunzip backup.sqlite3.gz
class DatabaseBackup
  CIPHER = "aes-256-cbc".freeze
  ITERATIONS = 600_000
  MAGIC = "Salted__".b.freeze

  attr_reader :created_on

  def self.passphrase
    ENV["BACKUP_PASSPHRASE"].presence
  end

  def self.recipient
    ENV["BACKUP_EMAIL"].presence || ENV["GMAIL_USERNAME"].presence
  end

  # Backups are only ever sent encrypted, to a known address.
  def self.configured?
    passphrase.present? && recipient.present?
  end

  # Finance records whose changes call for a fresh backup. Audits also catch
  # deleted transactions and categories.
  TRACKED_MODELS = [
    FinanceTransaction, FinanceCategory, FinanceBudget, FinancePeriod,
    FinanceUnit, FinanceUnitMembership, FinanceVoucherSequence
  ].freeze

  def self.changes_since?(time)
    TRACKED_MODELS.any? { |model| model.where(updated_at: time..).exists? } ||
      Audited::Audit.where(created_at: time..).exists?
  end

  def self.decrypt(data, passphrase:)
    data = data.b
    raise ArgumentError, "Not an encrypted backup" unless data.start_with?(MAGIC)

    salt = data.byteslice(8, 8)
    cipher = cipher_for(:decrypt, passphrase, salt)
    Zlib.gunzip(cipher.update(data.byteslice(16..)) + cipher.final)
  end

  def self.cipher_for(direction, passphrase, salt)
    key_and_iv = OpenSSL::KDF.pbkdf2_hmac(passphrase, salt: salt, iterations: ITERATIONS, length: 48, hash: "sha256")
    OpenSSL::Cipher.new(CIPHER).public_send(direction).tap do |cipher|
      cipher.key = key_and_iv.byteslice(0, 32)
      cipher.iv = key_and_iv.byteslice(32, 16)
    end
  end

  def initialize(passphrase: self.class.passphrase, created_on: Date.current)
    raise ArgumentError, "BACKUP_PASSPHRASE is not set" if passphrase.blank?

    @passphrase = passphrase
    @created_on = created_on
  end

  def filename
    "tmc-backup-#{created_on.iso8601}.sqlite3.gz.enc"
  end

  def data
    @data ||= encrypt(Zlib.gzip(snapshot))
  end

  private

  attr_reader :passphrase

  # SQLite's online backup API copies a consistent snapshot while the app
  # keeps running (unlike VACUUM INTO, it also works inside a transaction).
  def snapshot
    Dir.mktmpdir do |dir|
      path = File.join(dir, "backup.sqlite3")
      copy = SQLite3::Database.new(path)
      ActiveRecord::Base.connection_pool.with_connection do |connection|
        backup = SQLite3::Backup.new(copy, "main", connection.raw_connection, "main")
        backup.step(-1)
        backup.finish
      end
      copy.close
      File.binread(path)
    end
  end

  def encrypt(plain)
    salt = SecureRandom.random_bytes(8)
    cipher = self.class.cipher_for(:encrypt, passphrase, salt)
    MAGIC + salt + cipher.update(plain) + cipher.final
  end
end
