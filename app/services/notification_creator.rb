class NotificationCreator
  def self.call(actor:, title:, message:, notification_type:, link:, finance_unit: nil)
    can_publish = if finance_unit
      actor&.can_manage_finance_unit?(finance_unit)
    else
      actor&.notification_actor?
    end
    return unless can_publish

    notification = Notification.create!(
      actor: actor,
      title: title,
      message: message,
      notification_type: notification_type,
      link: link,
      finance_unit: finance_unit
    )

    PushDeliveryJob.perform_later(notification.id)

    notification
  end
end
