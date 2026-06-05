class NotificationRead < ApplicationRecord
  belongs_to :notification
  belongs_to :user

  validates :notification_id, uniqueness: { scope: :user_id }

  before_validation :set_read_at, on: :create

  private

  def set_read_at
    self.read_at ||= Time.current
  end
end
