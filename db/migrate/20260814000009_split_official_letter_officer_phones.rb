class SplitOfficialLetterOfficerPhones < ActiveRecord::Migration[8.1]
  def change
    rename_column :official_letters, :header_phone, :header_president_phone
    add_column :official_letters, :header_secretary_phone, :string
  end
end
