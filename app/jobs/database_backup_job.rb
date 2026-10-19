# Emails an encrypted copy of the database. Runs every night at 11pm (see
# config/recurring.yml) but only sends when finance records changed that day,
# plus every Sunday regardless, so there is always a copy at least weekly.
# "Send backup now" in Settings passes force: true.
class DatabaseBackupJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, Net::SMTPServerBusy, wait: 30.minutes, attempts: 3

  def perform(force: false)
    unless DatabaseBackup.configured?
      Rails.logger.warn("Database backup skipped: set BACKUP_PASSPHRASE (and BACKUP_EMAIL or GMAIL_USERNAME).")
      return
    end
    return unless force || Date.current.sunday? || DatabaseBackup.changes_since?(1.day.ago)

    BackupMailer.with(backup: DatabaseBackup.new).backup.deliver_now
  end
end
