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
  belongs_to :assigned_to, class_name: "User", inverse_of: :assigned_church_resolutions, optional: true
  has_one :official_letter, dependent: :nullify

  validates :title, :status, :priority, presence: true
  validates :number, presence: true, uniqueness: true

  before_validation :sync_completed_at_with_status
  before_validation :assign_number, on: :create

  scope :overdue, -> {
    where.not(status: :completed).where("due_date < ?", Date.current)
  }

  scope :due_soon, -> {
    where.not(status: :completed).where(due_date: Date.current..7.days.from_now.to_date)
  }

  scope :latest, -> {
    order(created_at: :desc)
  }

  def overdue?
    !completed? && due_date.present? && due_date < Date.current
  end

  # Postgres advisory lock keyed by model+year serializes number generation
  # without blocking unrelated reads/writes; the unique index on `number` is
  # the backstop if that were ever bypassed. Deliberately not `count + 1` /
  # `maximum + 1`, which race under concurrent writes.
  def self.next_number(year = Date.current.year)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{connection.quote("church_resolutions:#{year}")}))")
      last = where("number LIKE ?", "RES-#{year}-%").order(:number).last
      seq = last ? last.number.split("-").last.to_i + 1 : 1
      format("RES-%<year>d-%<seq>03d", year: year, seq: seq)
    end
  end

  private

  def sync_completed_at_with_status
    self.completed_at = completed? ? (completed_at || Time.current) : nil
  end

  def assign_number
    self.number ||= self.class.next_number
  end
end
