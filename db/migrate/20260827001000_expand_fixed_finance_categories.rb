class ExpandFixedFinanceCategories < ActiveRecord::Migration[8.1]
  class MigrationFinanceUnit < ActiveRecord::Base
    self.table_name = "finance_units"
  end

  class MigrationFinanceCategory < ActiveRecord::Base
    self.table_name = "finance_categories"
  end

  class MigrationFinanceTransaction < ActiveRecord::Base
    self.table_name = "finance_transactions"
  end

  CATALOG = [
    [ "tithe", "Tithe (Sawm a Pakhat)", "income", %w[church] ],
    [ "offering", "Offering (Thawhlawm)", "income", %w[church department] ],
    [ "special_offering", "Special Offering (Thawhlawm Bik)", "income", %w[church department] ],
    [ "thanksgiving_offering", "Thanksgiving Offering (Lawmthu Thawhlawm)", "income", %w[church department] ],
    [ "mission_fund", "Mission Fund (Mission Sum)", "income", %w[church fund] ],
    [ "building_fund", "Building Fund (Building Sum)", "income", %w[church fund] ],
    [ "member_contribution", "Member Contribution (Member Sum)", "income", %w[church department] ],
    [ "donation", "Donation (Thilpek)", "income", %w[church department fund] ],
    [ "fundraising", "Fundraising (Sum Tuakna)", "income", %w[church department] ],
    [ "opening_balance", "Opening Balance (Balance Hmasa)", "income", %w[church department fund] ],
    [ "other_income", "Other Income (Sum Lut Dang)", "income", %w[church department fund] ],
    [ "rent", "Church Rent (Biak In Rent)", "expense", %w[church department] ],
    [ "utilities", "Utilities (Electric, Gas & Water)", "expense", %w[church department] ],
    [ "food_refreshments", "Food & Refreshments (Ei leh In)", "expense", %w[church department] ],
    [ "transport", "Transportation (Kalna)", "expense", %w[church department] ],
    [ "ministry_program", "Worship & Ministry (Inkhawm Senso)", "expense", %w[church department] ],
    [ "mission_evangelism", "Mission & Evangelism (Mission Senso)", "expense", %w[church department fund] ],
    [ "children_ministry", "Children's Ministry (Naupang)", "expense", %w[church department] ],
    [ "youth_ministry", "Youth Ministry (Thalai)", "expense", %w[church department] ],
    [ "women_ministry", "Women's Ministry (Hmeichhe)", "expense", %w[church department] ],
    [ "pastoral_support", "Pastoral Support (Pastor Tanpuina)", "expense", %w[church] ],
    [ "guest_speaker", "Guest Speaker Gift (Speaker Thilpek)", "expense", %w[church department] ],
    [ "equipment_supplies", "Equipment & Supplies (Thil Mamawh)", "expense", %w[church department fund] ],
    [ "printing_stationery", "Printing & Stationery (Print & Office)", "expense", %w[church department] ],
    [ "maintenance_repair", "Maintenance & Repair (Siamthatna)", "expense", %w[church department fund] ],
    [ "fellowship_events", "Fellowship & Events (Inpumkhatna)", "expense", %w[church department] ],
    [ "charity_relief", "Charity & Relief (Tanpuina)", "expense", %w[church department fund] ],
    [ "fund_project", "Project Expense (Project Senso)", "expense", %w[church fund] ],
    [ "bank_fees", "Bank Fees (Bank Charge)", "expense", %w[church department fund] ],
    [ "other_expense", "Other Expense (Sum Chhuak Dang)", "expense", %w[church department fund] ]
  ].freeze

  DESCRIPTION = "System-defined finance category."

  def up
    before_snapshot = transaction_snapshot

    MigrationFinanceUnit.find_each do |unit|
      catalog_for(unit).each_with_index do |entry, position|
        code, name, category_type = entry
        category = MigrationFinanceCategory.find_or_initialize_by(
          finance_unit_id: unit.id,
          category_type: category_type,
          code: code
        )

        attributes = {
          name: name,
          description: DESCRIPTION,
          system_defined: true,
          position: position,
          updated_at: Time.current
        }

        if category.persisted?
          category.update_columns(**attributes)
        else
          category.assign_attributes(**attributes, created_at: Time.current)
          category.save!
        end
      end
    end

    verify_transaction_snapshot!(before_snapshot)
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "The expanded fixed catalog preserves finance entries and is not automatically contracted."
  end

  private

  def catalog_for(unit)
    CATALOG.select { |entry| entry.fetch(3).include?(unit.unit_type) }
  end

  def transaction_snapshot
    {
      count: MigrationFinanceTransaction.count,
      income: MigrationFinanceTransaction.where(transaction_type: "income").sum(:amount),
      expense: MigrationFinanceTransaction.where(transaction_type: "expense").sum(:amount)
    }
  end

  def verify_transaction_snapshot!(before_snapshot)
    return if transaction_snapshot == before_snapshot

    raise ActiveRecord::MigrationError,
          "Finance transaction count or figures changed while expanding fixed categories."
  end
end
