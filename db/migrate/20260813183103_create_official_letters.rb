class CreateOfficialLetters < ActiveRecord::Migration[8.1]
  def change
    create_table :official_letters do |t|
      t.string :reference_number, null: false
      t.date :letter_date, null: false
      t.string :recipient_name, null: false
      t.string :recipient_organization
      t.text :recipient_address
      t.string :subject, null: false
      t.text :body
      t.string :signatory_name
      t.string :signatory_role
      t.integer :status, null: false, default: 0
      t.references :church_resolution, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :official_letters, :reference_number, unique: true
  end
end
