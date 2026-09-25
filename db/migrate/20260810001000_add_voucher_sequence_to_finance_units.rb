class AddVoucherSequenceToFinanceUnits < ActiveRecord::Migration[8.1]
  def up
    add_column :finance_units, :voucher_sequence, :integer, null: false, default: 0

    execute <<~SQL.squish
      UPDATE finance_units
      SET voucher_sequence = COALESCE((
        SELECT MAX(finance_transactions.voucher_number)
        FROM finance_transactions
        WHERE finance_transactions.finance_unit_id = finance_units.id
          AND finance_transactions.transaction_type = 'expense'
      ), 0)
    SQL
  end

  def down
    remove_column :finance_units, :voucher_sequence
  end
end
