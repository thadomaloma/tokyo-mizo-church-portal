class CreateFinanceUnits < ActiveRecord::Migration[8.1]
  DEFAULT_UNITS = [
    [ "Main Church Finance", "main-church-finance", "church", 0 ],
    [ "Naupang Department", "naupang-department", "department", 10 ],
    [ "Thalai Department", "thalai-department", "department", 20 ],
    [ "Hmeichhe Department", "hmeichhe-department", "department", 30 ],
    [ "Building Sum", "building-sum", "fund", 40 ],
    [ "Mission Sum", "mission-sum", "fund", 50 ]
  ].freeze

  def up
    create_table :finance_units do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :unit_type, null: false, default: "department"
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :finance_units, :slug, unique: true
    add_index :finance_units, [ :active, :position ]

    create_table :finance_unit_memberships do |t|
      t.references :finance_unit, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false
      t.timestamps
    end
    add_index :finance_unit_memberships,
              [ :finance_unit_id, :user_id ],
              unique: true,
              name: :index_finance_unit_memberships_on_unit_and_user

    now = connection.quote(Time.current)
    DEFAULT_UNITS.each do |name, slug, unit_type, position|
      execute <<~SQL.squish
        INSERT INTO finance_units (name, slug, unit_type, active, position, created_at, updated_at)
        VALUES (#{connection.quote(name)}, #{connection.quote(slug)}, #{connection.quote(unit_type)}, TRUE, #{position}, #{now}, #{now})
      SQL
    end

    main_unit_id = select_value("SELECT id FROM finance_units WHERE slug = 'main-church-finance'")

    add_reference :finance_categories, :finance_unit, foreign_key: true
    add_reference :finance_transactions, :finance_unit, foreign_key: true
    add_reference :notifications, :finance_unit, foreign_key: { on_delete: :nullify }

    execute "UPDATE finance_categories SET finance_unit_id = #{main_unit_id}"
    execute "UPDATE finance_transactions SET finance_unit_id = #{main_unit_id}"

    change_column_null :finance_categories, :finance_unit_id, false
    change_column_null :finance_transactions, :finance_unit_id, false

    remove_index :finance_transactions, name: :index_finance_transactions_on_expense_voucher_number
    add_index :finance_transactions,
              [ :finance_unit_id, :voucher_number ],
              unique: true,
              where: "transaction_type = 'expense' AND voucher_number IS NOT NULL",
              name: :index_finance_transactions_on_unit_expense_voucher
  end

  def down
    remove_index :finance_transactions, name: :index_finance_transactions_on_unit_expense_voucher
    add_index :finance_transactions,
              :voucher_number,
              unique: true,
              where: "transaction_type = 'expense' AND voucher_number IS NOT NULL",
              name: :index_finance_transactions_on_expense_voucher_number

    remove_reference :notifications, :finance_unit, foreign_key: true
    remove_reference :finance_transactions, :finance_unit, foreign_key: true
    remove_reference :finance_categories, :finance_unit, foreign_key: true
    drop_table :finance_unit_memberships
    drop_table :finance_units
  end
end
