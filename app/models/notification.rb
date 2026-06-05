class Notification < ApplicationRecord
  belongs_to :actor, class_name: "User", optional: true
  has_many :notification_reads, dependent: :destroy

  validates :title, :message, :notification_type, presence: true

  scope :latest, -> { order(created_at: :desc) }
  scope :visible_for, ->(user) {
    user ? where.not(actor_id: user.id) : none
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
    notification_reads.exists?(user_id: user.id)
  end
end
