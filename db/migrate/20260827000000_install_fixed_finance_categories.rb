class InstallFixedFinanceCategories < ActiveRecord::Migration[8.1]
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
    [ "tithe", "Tithe (Sawm a Pakhat)", "income", "System-defined finance category.", %w[church] ],
    [ "offering", "Offering (Thawhlawm)", "income", "System-defined finance category.", %w[church department] ],
    [ "special_offering", "Special Offering (Thawhlawm Bik)", "income", "System-defined finance category.", %w[church department] ],
    [ "thanksgiving_offering", "Thanksgiving Offering (Lawmthu Thawhlawm)", "income", "System-defined finance category.", %w[church department] ],
    [ "mission_fund", "Mission Fund (Mission Sum)", "income", "System-defined finance category.", %w[church fund] ],
    [ "building_fund", "Building Fund (Building Sum)", "income", "System-defined finance category.", %w[church fund] ],
    [ "member_contribution", "Member Contribution (Member Sum)", "income", "System-defined finance category.", %w[church department] ],
    [ "donation", "Donation (Thilpek)", "income", "System-defined finance category.", %w[church department fund] ],
    [ "fundraising", "Fundraising (Sum Tuakna)", "income", "System-defined finance category.", %w[church department] ],
    [ "opening_balance", "Opening Balance (Balance Hmasa)", "income", "System-defined finance category.", %w[church department fund] ],
    [ "other_income", "Other Income (Sum Lut Dang)", "income", "System-defined finance category.", %w[church department fund] ],
    [ "rent", "Church Rent (Biak In Rent)", "expense", "System-defined finance category.", %w[church department] ],
    [ "utilities", "Utilities (Electric, Gas & Water)", "expense", "System-defined finance category.", %w[church department] ],
    [ "food_refreshments", "Food & Refreshments (Ei leh In)", "expense", "System-defined finance category.", %w[church department] ],
    [ "transport", "Transportation (Kalna)", "expense", "System-defined finance category.", %w[church department] ],
    [ "ministry_program", "Worship & Ministry (Inkhawm Senso)", "expense", "System-defined finance category.", %w[church department] ],
    [ "mission_evangelism", "Mission & Evangelism (Mission Senso)", "expense", "System-defined finance category.", %w[church department fund] ],
    [ "children_ministry", "Children's Ministry (Naupang)", "expense", "System-defined finance category.", %w[church department] ],
    [ "youth_ministry", "Youth Ministry (Thalai)", "expense", "System-defined finance category.", %w[church department] ],
    [ "women_ministry", "Women's Ministry (Hmeichhe)", "expense", "System-defined finance category.", %w[church department] ],
    [ "pastoral_support", "Pastoral Support (Pastor Tanpuina)", "expense", "System-defined finance category.", %w[church] ],
    [ "guest_speaker", "Guest Speaker Gift (Speaker Thilpek)", "expense", "System-defined finance category.", %w[church department] ],
    [ "equipment_supplies", "Equipment & Supplies (Thil Mamawh)", "expense", "System-defined finance category.", %w[church department fund] ],
    [ "printing_stationery", "Printing & Stationery (Print & Office)", "expense", "System-defined finance category.", %w[church department] ],
    [ "maintenance_repair", "Maintenance & Repair (Siamthatna)", "expense", "System-defined finance category.", %w[church department fund] ],
    [ "fellowship_events", "Fellowship & Events (Inpumkhatna)", "expense", "System-defined finance category.", %w[church department] ],
    [ "charity_relief", "Charity & Relief (Tanpuina)", "expense", "System-defined finance category.", %w[church department fund] ],
    [ "fund_project", "Project Expense (Project Senso)", "expense", "System-defined finance category.", %w[church fund] ],
    [ "bank_fees", "Bank Fees (Bank Charge)", "expense", "System-defined finance category.", %w[church department fund] ],
    [ "other_expense", "Other Expense (Sum Chhuak Dang)", "expense", "System-defined finance category.", %w[church department fund] ]
  ].freeze

  def up
    add_column :finance_categories, :code, :string
    add_column :finance_categories, :description, :string
    add_column :finance_categories, :system_defined, :boolean, null: false, default: false
    add_column :finance_categories, :position, :integer, null: false, default: 0

    MigrationFinanceCategory.reset_column_information
    before_snapshot = transaction_snapshot

    MigrationFinanceUnit.find_each do |unit|
      install_catalog_for(unit)
      map_legacy_categories_for(unit)
    end

    add_index :finance_categories,
              %i[finance_unit_id category_type code],
              unique: true,
              where: "code IS NOT NULL",
              name: "index_finance_categories_on_unit_type_code"

    verify_transaction_snapshot!(before_snapshot)
    verify_all_transactions_use_system_categories!
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Legacy categories were consolidated into fixed system categories without changing finance figures."
  end

  private

  def install_catalog_for(unit)
    catalog_for(unit).each_with_index do |entry, position|
      code, name, category_type, description = entry
      category = MigrationFinanceCategory
                   .where(finance_unit_id: unit.id, category_type: category_type)
                   .where("lower(btrim(name)) = ?", normalize(name))
                   .order(:id)
                   .first

      attributes = {
        code: code,
        name: name,
        description: description,
        system_defined: true,
        position: position
      }

      if category
        category.update_columns(**attributes, updated_at: Time.current)
      else
        MigrationFinanceCategory.create!(
          **attributes,
          finance_unit_id: unit.id,
          category_type: category_type,
          created_at: Time.current,
          updated_at: Time.current
        )
      end
    end
  end

  def map_legacy_categories_for(unit)
    targets = MigrationFinanceCategory
                .where(finance_unit_id: unit.id, system_defined: true)
                .index_by(&:code)

    MigrationFinanceCategory
      .where(finance_unit_id: unit.id, system_defined: false)
      .find_each do |legacy_category|
        target_code = mapped_code(legacy_category.name, legacy_category.category_type)
        target = targets[target_code] || targets.fetch("other_#{legacy_category.category_type}")

        MigrationFinanceTransaction
          .where(finance_category_id: legacy_category.id)
          .update_all(finance_category_id: target.id)
        legacy_category.delete
      end
  end

  def catalog_for(unit)
    CATALOG.select { |entry| entry.fetch(4).include?(unit.unit_type) }
  end

  def mapped_code(name, category_type)
    normalized_name = normalize(name)

    if category_type == "income"
      return "opening_balance" if normalized_name.include?("opening balance")
      return "tithe" if normalized_name.match?(/sawm\s*a?\s*pakhat|sawmapakhat|tithe|10%/)
      return "thanksgiving_offering" if normalized_name.match?(/thanksgiving|lawmthu/)
      return "special_offering" if normalized_name.match?(/kumthar|special.*offering|thawhlawm.*bik/)
      return "offering" if normalized_name.match?(/thawh\s*hlawm|thawhlawm|offering/)
      return "mission_fund" if normalized_name.match?(/mission/)
      return "building_fund" if normalized_name.match?(/building/)
      return "member_contribution" if normalized_name.match?(/member.*(sum|contribution)|member contribution/)
      return "fundraising" if normalized_name.match?(/fund.?rais|sum\s*tuak/)
      return "donation" if normalized_name.match?(/donation|thilpek|contribution/)

      "other_income"
    else
      return "rent" if normalized_name.match?(/rent|hmun\s*man/)
      return "utilities" if normalized_name.match?(/electric|gas|water|tui|internet|utility/)
      return "food_refreshments" if normalized_name.match?(/ei\s*leh\s*in|food|refreshment/)
      return "transport" if normalized_name.match?(/ralna|transport|travel|fare|fuel/)
      return "guest_speaker" if normalized_name.match?(/speaker|honorarium/)
      return "pastoral_support" if normalized_name.match?(/pastor|love\s*gift/)
      return "mission_evangelism" if normalized_name.match?(/mission|evangel|chanchin\s*tha/)
      return "children_ministry" if normalized_name.match?(/children|naupang/)
      return "youth_ministry" if normalized_name.match?(/youth|thalai/)
      return "women_ministry" if normalized_name.match?(/women|hmeichhe/)
      return "printing_stationery" if normalized_name.match?(/print|stationery/)
      return "maintenance_repair" if normalized_name.match?(/maintenance|repair|siamthat/)
      return "fellowship_events" if normalized_name.match?(/fellowship|event|inpumkhat/)
      return "charity_relief" if normalized_name.match?(/charity|relief|tanpuina/)
      return "equipment_supplies" if normalized_name.match?(/equipment|suppl|office|material/)
      return "bank_fees" if normalized_name.match?(/bank.*fee|charge/)
      return "ministry_program" if normalized_name.match?(/programme?|ministry|rawngbawl/)

      "other_expense"
    end
  end

  def normalize(value)
    value.to_s.downcase.strip.gsub(/\s+/, " ")
  end

  def transaction_snapshot
    {
      count: MigrationFinanceTransaction.count,
      income: amount_total("income"),
      expense: amount_total("expense")
    }
  end

  def amount_total(transaction_type)
    MigrationFinanceTransaction.where(transaction_type: transaction_type).sum(:amount)
  end

  def verify_transaction_snapshot!(before_snapshot)
    after_snapshot = transaction_snapshot
    return if before_snapshot == after_snapshot

    raise ActiveRecord::MigrationError,
          "Finance transaction count or figures changed while installing fixed categories."
  end

  def verify_all_transactions_use_system_categories!
    legacy_links = MigrationFinanceTransaction
                     .joins("INNER JOIN finance_categories ON finance_categories.id = finance_transactions.finance_category_id")
                     .where(finance_categories: { system_defined: false })
                     .count
    return if legacy_links.zero?

    raise ActiveRecord::MigrationError, "Some finance transactions still use legacy categories."
  end
end
