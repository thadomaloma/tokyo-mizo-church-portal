class NotificationCreator
  def self.call(actor:, title:, message:, notification_type:, link:)
    return unless actor&.notification_actor?

    Notification.create!(
      actor: actor,
      title: title,
      message: message,
      notification_type: notification_type,
      link: link
    )
  end
end
