class FinanceUnit < ApplicationRecord
  MAIN_SLUG = "main-church-finance"
  UNIT_TYPES = %w[church department fund].freeze
  # A new install starts with the main church ledger only; departments and
  # funds are added from Settings when the church actually needs them.
  DEFAULT_UNITS = [
    { name: "Main Church Finance", slug: MAIN_SLUG, unit_type: "church", position: 0 }
  ].freeze
  UNIT_TYPE_LABELS = { "church" => "Church", "department" => "Department", "fund" => "Fund" }.freeze

  has_many :finance_unit_memberships, dependent: :destroy
  has_many :users, through: :finance_unit_memberships
  has_many :finance_categories, dependent: :restrict_with_error
  has_many :finance_transactions, dependent: :restrict_with_error
  has_many :finance_voucher_sequences, dependent: :destroy
  has_many :finance_periods, dependent: :destroy
  has_many :finance_budgets, dependent: :destroy

  validates :name, :slug, :unit_type, presence: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }
  validates :unit_type, inclusion: { in: UNIT_TYPES }
  validates :bank_account_name, length: { maximum: 40 }

  normalizes :bank_account_name, with: ->(name) { name.squish.presence }
  validate :main_unit_must_remain_active
  validate :slug_cannot_change, on: :update
  validate :membership_roles_must_match_unit_type, on: :update

  before_validation :normalize_slug

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def self.main
    find_by!(slug: MAIN_SLUG)
  end

  # Display name of one of the unit's two accounts: "Cash", or the bank's
  # name when one is set (e.g. "Yucho Bank"), otherwise "Bank".
  def account_label(location)
    location.to_s == "bank" ? (bank_account_name.presence || "Bank") : "Cash"
  end

  def account_options
    FinanceTransaction::LOCATIONS.map { |location| [ account_label(location), location ] }
  end

  def main?
    slug == MAIN_SLUG
  end

  def membership_roles
    unit_type == "fund" ? %w[treasurer viewer] : FinanceUnitMembership::ROLES
  end

  private

  def normalize_slug
    self.slug = name.to_s.parameterize if slug.blank?
    self.slug = slug.to_s.parameterize
  end

  def main_unit_must_remain_active
    errors.add(:active, "must remain enabled for the main church ledger") if main? && !active?
  end

  def slug_cannot_change
    errors.add(:slug, "cannot be changed after the finance unit is created") if will_save_change_to_slug?
  end

  def membership_roles_must_match_unit_type
    return unless will_save_change_to_unit_type?
    return unless unit_type == "fund"
    return unless finance_unit_memberships.where(role: "finance_secretary").exists?

    errors.add(:unit_type, "cannot be changed to a fund while a Finance Secretary is assigned")
  end
end
