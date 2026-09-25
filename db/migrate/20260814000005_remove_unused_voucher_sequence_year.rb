class RemoveUnusedVoucherSequenceYear < ActiveRecord::Migration[8.1]
  # Leftover from an abandoned numbering design superseded by the
  # finance_voucher_sequences table (see CreateFinanceVoucherSequences).
  # Never used by any code path.
  def up
    remove_column :finance_units, :voucher_sequence_year, :integer if column_exists?(:finance_units, :voucher_sequence_year)
  end

  def down
    add_column :finance_units, :voucher_sequence_year, :integer unless column_exists?(:finance_units, :voucher_sequence_year)
  end
end
