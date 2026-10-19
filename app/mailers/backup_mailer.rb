class BackupMailer < ApplicationMailer
  def backup
    @backup = params[:backup]
    attachments[@backup.filename] = { mime_type: "application/octet-stream", content: @backup.data }

    mail to: DatabaseBackup.recipient,
         subject: "Tokyo Mizo Church Finance backup · #{@backup.created_on.strftime("%-d %b %Y")}"
  end
end
