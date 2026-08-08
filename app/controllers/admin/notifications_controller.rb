module Admin
  class NotificationsController < BaseController
    def show
      notification = Notification.visible_for(current_user).find(params[:id])
      mark_as_read(notification)

      redirect_to notification_destination(notification),
                  status: :see_other
    end

    def mark_all_as_read
      notification_ids = Notification.unread_for(current_user).pluck(:id)
      create_notification_reads(notification_ids)

      redirect_back fallback_location: admin_root_path,
                    status: :see_other,
                    notice: "Notifications cleared."
    end

    private

    def mark_as_read(notification)
      create_notification_reads([ notification.id ])
    end

    def create_notification_reads(notification_ids)
      return if notification_ids.empty?

      now = Time.current
      rows = notification_ids.map do |notification_id|
        {
          notification_id: notification_id,
          user_id: current_user.id,
          read_at: now,
          created_at: now,
          updated_at: now
        }
      end

      NotificationRead.insert_all(
        rows,
        unique_by: :index_notification_reads_on_notification_id_and_user_id
      )
    end

    def notification_destination(notification)
      link = notification.link.to_s
      return link if link.match?(Notification::INTERNAL_PATH_PATTERN)

      admin_root_path
    end
  end
end
