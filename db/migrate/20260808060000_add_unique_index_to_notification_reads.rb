class AddUniqueIndexToNotificationReads < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      DELETE FROM notification_reads AS duplicate
      USING notification_reads AS original
      WHERE duplicate.id > original.id
        AND duplicate.notification_id = original.notification_id
        AND duplicate.user_id = original.user_id
    SQL

    add_index :notification_reads,
              %i[notification_id user_id],
              unique: true,
              name: :index_notification_reads_on_notification_id_and_user_id
  end

  def down
    remove_index :notification_reads,
                 name: :index_notification_reads_on_notification_id_and_user_id
  end
end
