class RemoveLetterKindFromOfficialLetters < ActiveRecord::Migration[8.1]
  def change
    remove_column :official_letters, :letter_kind, :integer
  end
end
