class OfficialLetter < ApplicationRecord
  enum :status, { draft: 0, sent: 1 }

  belongs_to :church_resolution, optional: true
  belongs_to :created_by, class_name: "User", inverse_of: :official_letters

  validates :recipient_name, :subject, :letter_date, :status, presence: true
  validates :reference_number, presence: true, uniqueness: true, length: { maximum: 80 }
  validates :header_president_name, :header_secretary_name, length: { maximum: 120 }, allow_blank: true
  validates :header_president_phone, :header_secretary_phone, length: { maximum: 50 }, allow_blank: true
  validates :header_email, :header_website, length: { maximum: 255 }, allow_blank: true

  before_validation :assign_reference_number, on: :create

  scope :latest, -> { order(letter_date: :desc, created_at: :desc) }

  def document_heading
    "OFFICIAL LETTER"
  end

  def effective_salutation
    salutation.presence || "Rawngbawlpui duhtak,"
  end

  def effective_closing_line
    closing_line.presence || "Lawmthu nen,"
  end

  def effective_header_email
    header_email.presence || "admin@tokyomizochurch.org"
  end

  def effective_header_website
    header_website.presence || "tokyomizochurch.org"
  end

  def local_president_phone
    local_phone_number(header_president_phone)
  end

  def local_secretary_phone
    local_phone_number(header_secretary_phone)
  end

  # Same Postgres advisory-lock pattern as ChurchResolution.next_number:
  # serializes generation per model+year without blocking unrelated reads,
  # backed by the unique index on `reference_number` as a safety net.
  def self.next_reference_number(year = Date.current.year)
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{connection.quote("official_letters:#{year}")}))")
      last = where("reference_number LIKE ?", "TMC/#{year}/%").order(:reference_number).last
      seq = last ? last.reference_number.split("/").last.to_i + 1 : 1
      format("TMC/%<year>d/%<seq>03d", year: year, seq: seq)
    end
  end

  private

  def local_phone_number(value)
    value.to_s.strip.sub(/\A\+?81[\s-]*/, "")
  end

  def assign_reference_number
    self.reference_number ||= self.class.next_reference_number(letter_date&.year || Date.current.year)
  end
end
