class RemoveUnusedVoucherSequenceYear < ActiveRecord::Migration[8.1]
  # Leftover from an abandoned numbering design superseded by the
  # finance_voucher_sequences table (see CreateFinanceVoucherSequences).
  # Never used by any code path.
  def up
    remove_column :finance_units, :voucher_sequence_year, :integer
  end

  def down
    add_column :finance_units, :voucher_sequence_year, :integer
  end
end
