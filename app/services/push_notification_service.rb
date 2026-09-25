class PushNotificationService
  FINANCE_TITLE = "Finance Update".freeze
  FINANCE_BODY = "TMC Portal-ah finance record siamthat a ni.".freeze

  def self.deliver(notification)
    new(notification).deliver
  end

  def initialize(notification)
    @notification = notification
  end

  def deliver
    return unless Rails.application.config.x.vapid.configured?

    subscriptions.find_each { |subscription| deliver_to(subscription) }
  end

  private

  attr_reader :notification

  def subscriptions
    PushSubscription.where(user_id: notification.recipients.map(&:id))
  end

  def deliver_to(subscription)
    Webpush.payload_send(
      message: payload,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth_key,
      vapid: vapid_options,
      ttl: 60 * 60 * 24
    )
    subscription.update_column(:last_used_at, Time.current)
  rescue Webpush::ExpiredSubscription, Webpush::InvalidSubscription
    subscription.destroy
  rescue Webpush::ResponseError => e
    Rails.logger.warn(
      "PushNotificationService: delivery failed for subscription #{subscription.id} " \
      "(#{e.response.code} #{e.response.message})"
    )
  rescue StandardError => e
    # Network/DNS/TLS failures surface as plain Ruby errors, not
    # Webpush::ResponseError. They say nothing about whether the subscription
    # itself is valid, so it is logged and left in place rather than deleted.
    Rails.logger.warn(
      "PushNotificationService: unexpected error delivering to subscription #{subscription.id}: " \
      "#{e.class} - #{e.message}"
    )
  end

  def payload
    {
      title: title,
      body: body,
      url: Rails.application.routes.url_helpers.admin_notification_path(notification),
      icon: "/icon-192.png"
    }.to_json
  end

  def title
    finance? ? FINANCE_TITLE : notification.title
  end

  def body
    finance? ? FINANCE_BODY : notification.message
  end

  def finance?
    notification.notification_type == "finance"
  end

  def vapid_options
    {
      subject: Rails.application.config.x.vapid.subject,
      public_key: Rails.application.config.x.vapid.public_key,
      private_key: Rails.application.config.x.vapid.private_key
    }
  end
end
