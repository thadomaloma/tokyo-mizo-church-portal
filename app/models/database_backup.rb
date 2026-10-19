require "zlib"

# A copy of the whole database (records, cache and jobs all live in one
# SQLite file), gzipped and encrypted with BACKUP_PASSPHRASE.
#
# The file is exactly what `openssl enc -aes-256-cbc -pbkdf2` writes, so a
# backup can be opened on any computer without this app:
#
#   openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -md sha256 \
#     -in tmc-backup-2026-10-19-2300.sqlite3.gz.enc -out backup.sqlite3.gz
#   gunzip backup.sqlite3.gz
class DatabaseBackup
  CIPHER = "aes-256-cbc".freeze
  ITERATIONS = 600_000
  MAGIC = "Salted__".b.freeze
  LAST_UPLOAD_CACHE_KEY = "database_backup/last_upload".freeze
  COPY_ATTEMPTS = 20

  attr_reader :created_at

  def self.passphrase
    ENV["BACKUP_PASSPHRASE"].presence
  end

  # Backups are only ever stored encrypted, in the R2 bucket.
  def self.configured?
    passphrase.present? && R2Bucket.configured?
  end

  # { "filename" =>, "bytes" =>, "uploaded_at" => } of the latest upload, for
  # Settings; nil when none is known.
  def self.last_upload
    Rails.cache.read(LAST_UPLOAD_CACHE_KEY)
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

  def initialize(passphrase: self.class.passphrase, created_at: Time.current)
    raise ArgumentError, "BACKUP_PASSPHRASE is not set" if passphrase.blank?

    @passphrase = passphrase
    @created_at = created_at
  end

  def filename
    "tmc-backup-#{created_at.strftime("%Y-%m-%d-%H%M")}.sqlite3.gz.enc"
  end

  def data
    @data ||= encrypt(Zlib.gzip(snapshot))
  end

  def upload!(bucket = R2Bucket.new)
    bucket.put(filename, data)
    Rails.cache.write(LAST_UPLOAD_CACHE_KEY, { "filename" => filename, "bytes" => data.bytesize, "uploaded_at" => Time.current })
  end

  private

  attr_reader :passphrase

  # SQLite's online backup API, on a connection of its own: in WAL mode it
  # reads the last committed state without waiting for the app's writers.
  # A copy that did not finish is an error, never an empty upload.
  def snapshot
    Dir.mktmpdir do |dir|
      path = File.join(dir, "backup.sqlite3")
      source = SQLite3::Database.new(database_path)
      copy = SQLite3::Database.new(path)
      copy_all(SQLite3::Backup.new(copy, "main", source, "main"))
      copy.close
      source.close

      File.binread(path).tap do |bytes|
        raise "Backup copy is not a SQLite database" unless bytes.start_with?("SQLite format 3\0")
      end
    end
  end

  def copy_all(backup)
    COPY_ATTEMPTS.times do
      case backup.step(-1)
      when SQLite3::Constants::ErrorCode::DONE then return
      when SQLite3::Constants::ErrorCode::BUSY, SQLite3::Constants::ErrorCode::LOCKED then sleep 0.5
      else raise "SQLite backup failed"
      end
    end
    raise "Database stayed busy; backup not taken"
  ensure
    backup.finish
  end

  def database_path
    Rails.root.join(ActiveRecord::Base.connection_db_config.database).to_s
  end

  def encrypt(plain)
    salt = SecureRandom.random_bytes(8)
    cipher = self.class.cipher_for(:encrypt, passphrase, salt)
    MAGIC + salt + cipher.update(plain) + cipher.final
  end
end
