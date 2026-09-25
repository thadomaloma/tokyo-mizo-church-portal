class AddYearToFinanceVouchers < ActiveRecord::Migration[8.1]
  class MigrationFinanceTransaction < ActiveRecord::Base
    self.table_name = "finance_transactions"
  end

  def up
    add_column :finance_transactions, :voucher_year, :integer

    backfill_voucher_year

    remove_index :finance_transactions, name: "index_finance_transactions_on_unit_expense_voucher"
    add_index :finance_transactions,
              %i[finance_unit_id voucher_year voucher_number],
              unique: true,
              where: "((transaction_type = 'expense') AND (voucher_number IS NOT NULL))",
              name: "index_finance_transactions_on_unit_year_expense_voucher"
  end

  def down
    remove_index :finance_transactions, name: "index_finance_transactions_on_unit_year_expense_voucher"
    add_index :finance_transactions,
              %i[finance_unit_id voucher_number],
              unique: true,
              where: "((transaction_type = 'expense') AND (voucher_number IS NOT NULL))",
              name: "index_finance_transactions_on_unit_expense_voucher"

    remove_column :finance_transactions, :voucher_year
  end

  private

  # Pure display metadata backfilled from each row's own transaction_date —
  # does not touch the existing voucher_number values, so no historical
  # voucher is renumbered or reused.
  def backfill_voucher_year
    MigrationFinanceTransaction.reset_column_information
    MigrationFinanceTransaction.where(transaction_type: "expense").where.not(voucher_number: nil).find_each do |transaction|
      year = transaction.transaction_date&.year || Date.current.year
      transaction.update_column(:voucher_year, year)
    end
  end
end
