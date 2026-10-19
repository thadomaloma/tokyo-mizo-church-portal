# Uploads an encrypted copy of the database to the Cloudflare R2 bucket.
# Runs every night at 11pm (see config/recurring.yml) but only uploads when
# finance records changed that day, plus every Sunday regardless, so there is
# always a copy at least weekly. "Send backup now" in Settings passes
# force: true.
class DatabaseBackupJob < ApplicationJob
  queue_as :default

  retry_on R2Bucket::UploadError, Net::OpenTimeout, Net::ReadTimeout, wait: 30.minutes, attempts: 3

  def perform(force: false)
    unless DatabaseBackup.configured?
      Rails.logger.warn("Database backup skipped: set BACKUP_PASSPHRASE and the R2_ variables.")
      return
    end
    return unless force || Date.current.sunday? || DatabaseBackup.changes_since?(1.day.ago)

    backup = DatabaseBackup.new
    backup.upload!
    Rails.logger.info("Database backup uploaded to R2: #{backup.filename} (#{backup.data.bytesize} bytes)")
  end
end
