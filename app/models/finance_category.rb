class FinanceCategory < ApplicationRecord
  SYSTEM_CATALOG = [
    { code: "tithe", name: "Tithe (Sawm a Pakhat)", category_type: "income", unit_types: %w[church] },
    { code: "offering", name: "Offering (Thawhlawm)", category_type: "income", unit_types: %w[church department] },
    { code: "special_offering", name: "Special Offering (Thawhlawm Bik)", category_type: "income", unit_types: %w[church department] },
    { code: "thanksgiving_offering", name: "Thanksgiving Offering (Lawmthu Thawhlawm)", category_type: "income", unit_types: %w[church department] },
    { code: "mission_fund", name: "Mission Fund (Mission Sum)", category_type: "income", unit_types: %w[church fund] },
    { code: "building_fund", name: "Building Fund (Building Sum)", category_type: "income", unit_types: %w[church fund] },
    { code: "member_contribution", name: "Member Contribution (Member Sum)", category_type: "income", unit_types: %w[church department] },
    { code: "donation", name: "Donation (Thilpek)", category_type: "income", unit_types: %w[church department fund] },
    { code: "fundraising", name: "Fundraising (Sum Tuakna)", category_type: "income", unit_types: %w[church department] },
    { code: "opening_balance", name: "Opening Balance (Balance Hmasa)", category_type: "income", unit_types: %w[church department fund] },
    { code: "other_income", name: "Other Income (Sum Lut Dang)", category_type: "income", unit_types: %w[church department fund] },
    { code: "rent", name: "Church Rent (Biak In Rent)", category_type: "expense", unit_types: %w[church department] },
    { code: "utilities", name: "Utilities (Electric, Gas & Water)", category_type: "expense", unit_types: %w[church department] },
    { code: "food_refreshments", name: "Food & Refreshments (Ei leh In)", category_type: "expense", unit_types: %w[church department] },
    { code: "transport", name: "Transportation (Kalna)", category_type: "expense", unit_types: %w[church department] },
    { code: "ministry_program", name: "Worship & Ministry (Inkhawm Senso)", category_type: "expense", unit_types: %w[church department] },
    { code: "mission_evangelism", name: "Mission & Evangelism (Mission Senso)", category_type: "expense", unit_types: %w[church department fund] },
    { code: "children_ministry", name: "Children's Ministry (Naupang)", category_type: "expense", unit_types: %w[church department] },
    { code: "youth_ministry", name: "Youth Ministry (Thalai)", category_type: "expense", unit_types: %w[church department] },
    { code: "women_ministry", name: "Women's Ministry (Hmeichhe)", category_type: "expense", unit_types: %w[church department] },
    { code: "pastoral_support", name: "Pastoral Support (Pastor Tanpuina)", category_type: "expense", unit_types: %w[church] },
    { code: "guest_speaker", name: "Guest Speaker Gift (Speaker Thilpek)", category_type: "expense", unit_types: %w[church department] },
    { code: "equipment_supplies", name: "Equipment & Supplies (Thil Mamawh)", category_type: "expense", unit_types: %w[church department fund] },
    { code: "printing_stationery", name: "Printing & Stationery (Print & Office)", category_type: "expense", unit_types: %w[church department] },
    { code: "maintenance_repair", name: "Maintenance & Repair (Siamthatna)", category_type: "expense", unit_types: %w[church department fund] },
    { code: "fellowship_events", name: "Fellowship & Events (Inpumkhatna)", category_type: "expense", unit_types: %w[church department] },
    { code: "charity_relief", name: "Charity & Relief (Tanpuina)", category_type: "expense", unit_types: %w[church department fund] },
    { code: "fund_project", name: "Project Expense (Project Senso)", category_type: "expense", unit_types: %w[church fund] },
    { code: "bank_fees", name: "Bank Fees (Bank Charge)", category_type: "expense", unit_types: %w[church department fund] },
    { code: "other_expense", name: "Other Expense (Sum Chhuak Dang)", category_type: "expense", unit_types: %w[church department fund] }
  ].freeze

  SYSTEM_DESCRIPTION = "System-defined finance category.".freeze

  audited

  has_many :finance_transactions, dependent: :restrict_with_error
  belongs_to :finance_unit

  validates :name, presence: true
  validates :name, uniqueness: { scope: %i[finance_unit_id category_type], case_sensitive: false }
  validates :category_type, presence: true, inclusion: { in: %w[income expense] }
  validates :code, :description, presence: true, if: :system_defined?
  validates :code, uniqueness: { scope: %i[finance_unit_id category_type] }, allow_nil: true
  validate :category_type_cannot_change_when_used, on: :update
  validate :finance_unit_cannot_change_when_used, on: :update
  validate :system_definition_cannot_change, on: :update

  before_validation :assign_default_finance_unit, on: :create
  before_destroy :prevent_system_category_removal

  scope :income, -> { where(category_type: "income") }
  scope :expense, -> { where(category_type: "expense") }
  scope :system_defined, -> { where(system_defined: true) }
  scope :for_transaction_type, ->(transaction_type) {
    normalized_type = transaction_type.to_s

    normalized_type.in?(%w[income expense]) ? where(category_type: normalized_type) : none
  }

  def self.system_catalog_for(finance_unit)
    SYSTEM_CATALOG.select { |entry| entry.fetch(:unit_types).include?(finance_unit.unit_type) }
  end

  def self.install_system_catalog_for!(finance_unit)
    system_catalog_for(finance_unit).each_with_index do |entry, position|
      category = find_or_initialize_by(
        finance_unit: finance_unit,
        category_type: entry.fetch(:category_type),
        code: entry.fetch(:code)
      )
      category.assign_attributes(
        name: entry.fetch(:name),
        description: SYSTEM_DESCRIPTION,
        system_defined: true,
        position: position
      )
      if category.persisted? && category.system_defined?
        category.update_columns(
          name: entry.fetch(:name),
          description: SYSTEM_DESCRIPTION,
          position: position,
          updated_at: Time.current
        )
      else
        category.save!
      end
    end
  end

  def option_label
    name
  end

  private

  def assign_default_finance_unit
    self.finance_unit ||= FinanceUnit.main
  end

  def category_type_cannot_change_when_used
    return unless will_save_change_to_category_type?
    return unless finance_transactions.exists?

    errors.add(:category_type, "cannot be changed after finance entries use this category")
  end

  def finance_unit_cannot_change_when_used
    return unless will_save_change_to_finance_unit_id?
    return unless finance_transactions.exists?

    errors.add(:finance_unit, "cannot be changed after finance entries use this category")
  end

  def system_definition_cannot_change
    return unless system_defined_was
    return unless will_save_change_to_code? || will_save_change_to_name? ||
                  will_save_change_to_description? || will_save_change_to_category_type? ||
                  will_save_change_to_finance_unit_id?

    errors.add(:base, "System finance categories cannot be edited")
  end

  def prevent_system_category_removal
    return unless system_defined?

    errors.add(:base, "System finance categories cannot be deleted")
    throw :abort
  end
end
