class ChurchEvent < ApplicationRecord
  belongs_to :created_by, class_name: "User"

  validates :title, :start_date, presence: true

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
end
