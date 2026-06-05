class ChurchResolution < ApplicationRecord
  enum :status, {
    pending: 0,
    in_progress: 1,
    completed: 2,
    cancelled: 3
  }

  enum :priority, {
    low: 0,
    normal: 1,
    high: 2,
    urgent: 3
  }

  belongs_to :meeting_minute, optional: true
  belongs_to :assigned_to, class_name: "User", optional: true

  scope :overdue, -> {
    where.not(status: :completed).where("due_date < ?", Date.current)
  }

  scope :latest, -> {
    order(created_at: :desc)
  }
end
