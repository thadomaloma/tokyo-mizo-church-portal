# Active Storage and Action Cable are no longer loaded (nothing is uploaded
# and nothing is broadcast), so their tables are dead weight.
class DropUnusedFrameworkTables < ActiveRecord::Migration[8.1]
  def up
    drop_table :active_storage_variant_records, if_exists: true
    drop_table :active_storage_attachments, if_exists: true
    drop_table :active_storage_blobs, if_exists: true
    drop_table :solid_cable_messages, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
