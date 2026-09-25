class CreateFinanceVoucherSequences < ActiveRecord::Migration[8.1]
  class MigrationFinanceTransaction < ActiveRecord::Base
    self.table_name = "finance_transactions"
  end

  class MigrationFinanceVoucherSequence < ActiveRecord::Base
    self.table_name = "finance_voucher_sequences"
  end

  def up
    create_table :finance_voucher_sequences do |t|
      t.references :finance_unit, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :next_number, null: false, default: 0

      t.timestamps
    end

    add_index :finance_voucher_sequences, %i[finance_unit_id year], unique: true

    seed_sequences_from_existing_vouchers
  end

  def down
    drop_table :finance_voucher_sequences
  end

  private

  # Seeds each (finance_unit, year) counter to the highest voucher_number
  # already issued for that combination, so numbering continues forward
  # without colliding with vouchers assigned before this migration ran.
  def seed_sequences_from_existing_vouchers
    MigrationFinanceTransaction.reset_column_information
    MigrationFinanceVoucherSequence.reset_column_information

    MigrationFinanceTransaction
      .where(transaction_type: "expense")
      .where.not(voucher_number: nil, voucher_year: nil)
      .group(:finance_unit_id, :voucher_year)
      .maximum(:voucher_number)
      .each do |(finance_unit_id, year), max_number|
        MigrationFinanceVoucherSequence.create!(
          finance_unit_id: finance_unit_id,
          year: year,
          next_number: max_number
        )
      end
  end
end
