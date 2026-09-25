class AddLetterheadContactsToOfficialLetters < ActiveRecord::Migration[8.1]
  def change
    add_column :official_letters, :header_president_name, :string
    add_column :official_letters, :header_secretary_name, :string
    add_column :official_letters, :header_phone, :string
    add_column :official_letters, :header_email, :string
    add_column :official_letters, :header_website, :string
  end
end
