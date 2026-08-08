class MeetingMinute < ApplicationRecord
  belongs_to :uploaded_by, class_name: "User", inverse_of: :meeting_minutes
  has_many :church_resolutions, dependent: :nullify

  has_one_attached :pdf_file
  has_one_attached :secretary_signature

  validates :title, :meeting_type, :meeting_date, presence: true
  validates :pdf_file, presence: true, if: :archive_only?
  validate :pdf_file_must_be_valid
  validate :secretary_signature_must_be_png

  before_validation :sync_attendance_from_present_member_ids,
                    unless: :archive_only?
  after_save :sync_follow_up_resolutions!,
             unless: :archive_only?

  scope :latest, -> {
    order(meeting_date: :desc, created_at: :desc)
  }

  scope :regular_records, -> {
    where(archive_only: false)
  }

  scope :pdf_archives, -> {
    where(archive_only: true)
  }

  def recorded_sections_count
    [
      attendees,
      absentees,
      call_to_order,
      reports,
      previous_minutes,
      agenda_items,
      motions,
      action_items,
      adjournment
    ].count(&:present?)
  end

  def archive_only?
    archive_only
  end

  def present_member_ids=(ids)
    super(Array(ids).reject(&:blank?).map(&:to_i).uniq)
  end

  def sync_follow_up_resolutions!
    follow_up_resolution_titles.each do |title|
      resolution = church_resolutions.find_or_initialize_by(title: title)
      next unless resolution.new_record?

      resolution.description =
        "Auto-created from follow-up action in #{self.title}.\n\n#{title}"
      resolution.status = :pending
      resolution.priority = :normal
      resolution.due_date = next_meeting_date
      resolution.save!
    end
  end

  private

  def follow_up_resolution_titles
    plain_follow_up_actions
      .lines
      .map { |line| line.gsub(/\A(?:[-*•]\s*|\d+[\.)]\s*)/, "").squish }
      .reject(&:blank?)
      .uniq
  end

  def plain_follow_up_actions
    content = action_items.to_s
    return "" if content.blank?

    text =
      if content.match?(/<\/?[a-z][\s\S]*>/i)
        content
          .gsub(/<br\s*\/?>/i, "\n")
          .gsub(/<\/(li|p|div|h[1-6])>/i, "\n")
          .then { |html| ActionView::Base.full_sanitizer.sanitize(html) }
      else
        content
      end

    CGI.unescapeHTML(text)
  end

  def sync_attendance_from_present_member_ids
    members = User.active.order(:role, :name).to_a
    present_ids = present_member_ids.map(&:to_i)
    present_members = members.select { |member| present_ids.include?(member.id) }
    absent_members = members.reject { |member| present_ids.include?(member.id) }

    self.attendees = member_list(present_members)
    self.absentees = member_list(absent_members)
  end

  def member_list(members)
    members.map.with_index(1) do |member, index|
      "#{index}. #{member.name} - #{member.role.humanize}"
    end.join("\n")
  end

  def secretary_signature_must_be_png
    return unless secretary_signature.attached?

    errors.add(:secretary_signature, "must be smaller than 5 MB") if secretary_signature.byte_size > 5.megabytes
    return if secretary_signature.content_type == "image/png"

    errors.add(:secretary_signature, "must be a PNG file")
  end

  def pdf_file_must_be_valid
    return unless pdf_file.attached?

    errors.add(:pdf_file, "must be a PDF file") unless pdf_file.content_type == "application/pdf"
    errors.add(:pdf_file, "must be smaller than 20 MB") if pdf_file.byte_size > 20.megabytes
  end
end
