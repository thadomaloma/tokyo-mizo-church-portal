module Admin
  class NotificationsController < BaseController
    def show
      notification = Notification.visible_for(current_user).find(params[:id])
      mark_as_read(notification)

      redirect_to notification.link.presence || admin_root_path,
                  status: :see_other
    end

    def mark_all_as_read
      Notification.unread_for(current_user).find_each do |notification|
        mark_as_read(notification)
      end

      redirect_back fallback_location: admin_root_path,
                    status: :see_other,
                    notice: "Notifications cleared."
    end

    private

    def mark_as_read(notification)
      NotificationRead.find_or_create_by!(
        notification_id: notification.id,
        user_id: current_user.id
      )
    end
  end
end
