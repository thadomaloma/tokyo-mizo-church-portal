class Notification < ApplicationRecord
  INTERNAL_PATH_PATTERN = %r{\A/(?!/)[^\\\x00-\x1F\x7F]*\z}

  TYPES = %w[finance church_event meeting_minutes resolution official_letter member].freeze

  TYPE_ICONS = {
    "finance" => "banknotes",
    "church_event" => "calendar-days",
    "meeting_minutes" => "document-text",
    "resolution" => "clipboard-document-check",
    "official_letter" => "envelope",
    "member" => "user-plus"
  }.freeze
  DEFAULT_ICON = "bell"

  belongs_to :actor,
             class_name: "User",
             inverse_of: :authored_notifications,
             optional: true
  belongs_to :finance_unit, optional: true
  has_many :notification_reads, dependent: :destroy

  validates :title, :message, presence: true
  validates :notification_type, presence: true, inclusion: { in: TYPES }
  validates :link,
            format: {
              with: INTERNAL_PATH_PATTERN,
              message: "must be an internal path"
            },
            allow_blank: true

  scope :latest, -> { order(created_at: :desc) }
  scope :visible_for, ->(user) {
    if user
      accessible_unit_ids = user.accessible_finance_units.select(:id)
      visible = where(actor_id: nil).or(where.not(actor_id: user.id))
      visible.where(finance_unit_id: nil).or(visible.where(finance_unit_id: accessible_unit_ids))
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

  def icon
    TYPE_ICONS.fetch(notification_type, DEFAULT_ICON)
  end

  # Mirrors `visible_for` from the notification's side: who is allowed to see
  # this specific notification. Reuses the same authorization method the
  # in-app scope relies on so push delivery can never drift from it.
  def recipients
    scope = User.active.where.not(id: actor_id)
    return scope.to_a unless finance_unit

    scope.includes(:finance_unit_memberships).select { |user| user.can_view_finance_unit?(finance_unit) }
  end
end
