class ChurchEvent < ApplicationRecord
  belongs_to :created_by, class_name: "User", inverse_of: :church_events

  validates :title, :start_date, presence: true
  validate :end_date_cannot_precede_start_date

  scope :upcoming, -> {
    where("start_date >= ?", Time.current).order(start_date: :asc)
  }

  scope :this_month, -> {
    where(
      start_date:
      Time.current.beginning_of_month..
      Time.current.end_of_month
    )
  }

  scope :today, -> {
    where(
      start_date:
      Time.current.beginning_of_day..
      Time.current.end_of_day
    )
  }

  private

  def end_date_cannot_precede_start_date
    return if start_date.blank? || end_date.blank? || end_date >= start_date

    errors.add(:end_date, "cannot be before the start date and time")
  end
end
