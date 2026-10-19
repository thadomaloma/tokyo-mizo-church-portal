module Admin
  # "Send backup now" in Settings: queues the nightly backup job, forced to send.
  class BackupsController < BaseController
    before_action :require_super_admin!

    rate_limit to: 3, within: 1.hour,
               with: -> { redirect_to admin_settings_path, alert: "A backup was sent recently. Please wait before sending another." }

    def create
      if DatabaseBackup.configured?
        DatabaseBackupJob.perform_later(force: true)
        redirect_to admin_settings_path, notice: "Backup started. It will appear in Cloudflare R2 within a minute."
      else
        redirect_to admin_settings_path, alert: "Set BACKUP_PASSPHRASE and the R2_ variables on Railway before sending backups."
      end
    end
  end
end
