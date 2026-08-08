class Notification < ApplicationRecord
  INTERNAL_PATH_PATTERN = /\A\/(?!\/)[^\r\n]*\z/

  belongs_to :actor,
             class_name: "User",
             inverse_of: :authored_notifications,
             optional: true
  has_many :notification_reads, dependent: :destroy

  validates :title, :message, :notification_type, presence: true
  validates :link,
            format: {
              with: INTERNAL_PATH_PATTERN,
              message: "must be an internal path"
            },
            allow_blank: true

  scope :latest, -> { order(created_at: :desc) }
  scope :visible_for, ->(user) {
    if user
      where(actor_id: nil).or(where.not(actor_id: user.id))
    else
      none
    end
  }
  scope :visible_to, ->(user) { visible_for(user) }

  def self.unread_for(user)
    return none unless user

    visible_to(user).where.not(
      id: NotificationRead
            .where(user_id: user.id)
            .select(:notification_id)
    )
  end

  def read_by?(user)
    return false unless user

    if notification_reads.loaded?
      notification_reads.any? { |notification_read| notification_read.user_id == user.id }
    else
      notification_reads.exists?(user_id: user.id)
    end
  end
end
