class PushDeliveryJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(notification_id)
    notification = Notification.find(notification_id)

    PushNotificationService.deliver(notification)
  end
end
