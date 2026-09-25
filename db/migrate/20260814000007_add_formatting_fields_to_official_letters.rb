class AddFormattingFieldsToOfficialLetters < ActiveRecord::Migration[8.1]
  def change
    add_column :official_letters, :letter_kind, :integer, null: false, default: 0
    add_column :official_letters, :salutation, :string
    add_column :official_letters, :closing_line, :string
  end
end
