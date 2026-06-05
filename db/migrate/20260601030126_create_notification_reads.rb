class CreateNotificationReads < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_reads do |t|
      t.references :notification, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :read_at

      t.timestamps
    end
  end
end
