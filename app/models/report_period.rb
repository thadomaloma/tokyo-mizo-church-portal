# A run of whole months within one year, as chosen on the report page
# (e.g. February–May 2026). Knows its date range, its labels and the
# equally long period just before it, which the report compares against.
class ReportPeriod
  attr_reader :year, :start_month, :end_month

  def self.from_params(params, today: Date.current)
    year = params[:year].to_i
    year = today.year unless year.positive?
    start_month, end_month = [ month_param(params[:start_month], 1), month_param(params[:end_month], today.month) ].minmax
    new(year, start_month, end_month)
  end

  def self.month_param(value, fallback)
    month = value.to_i
    month.between?(1, 12) ? month : fallback
  end
  private_class_method :month_param

  def initialize(year, start_month, end_month)
    @year = year
    @start_month = start_month
    @end_month = end_month
  end

  def start_date = Date.new(year, start_month, 1)
  def end_date = Date.new(year, end_month, -1)
  def range = start_date..end_date
  def month_count = end_month - start_month + 1
  def single_month? = start_month == end_month

  def months
    (start_month..end_month).map { |month| Date.new(year, month, 1) }
  end

  def label
    return "#{Date::MONTHNAMES[start_month]} #{year}" if single_month?

    "#{Date::MONTHNAMES[start_month]} - #{Date::MONTHNAMES[end_month]} #{year}"
  end

  def caption
    single_month? ? label : "#{label}, up to #{Date::MONTHNAMES[end_month]}"
  end

  # The same number of months immediately before this period.
  def previous_range
    (start_date << month_count)...start_date
  end

  def previous_label
    first = previous_range.begin
    last = start_date - 1
    return first.strftime("%B %Y") if first.month == last.month && first.year == last.year
    return "#{first.strftime('%B')} - #{last.strftime('%B %Y')}" if first.year == last.year

    "#{first.strftime('%B %Y')} - #{last.strftime('%B %Y')}"
  end

  def filename
    "#{year}_#{start_month.to_s.rjust(2, '0')}_to_#{end_month.to_s.rjust(2, '0')}_#{Date.current}"
  end
end
