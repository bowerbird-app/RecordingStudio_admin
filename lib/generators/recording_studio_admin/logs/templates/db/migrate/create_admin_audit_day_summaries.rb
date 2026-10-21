# frozen_string_literal: true

class CreateAdminAuditDaySummaries < ActiveRecord::Migration[8.1]
  TABLE = "admin_audit_day_summaries"
  IDENTITY_INDEX = "index_admin_audit_day_summaries_identity"

  def up
    RecordingStudioLogs::Schema.install_runs!(connection)

    return if connection.data_source_exists?(TABLE)

    create_table TABLE, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.date :day, null: false
      t.uuid :root_recording_id
      t.string :resource_key
      t.string :action_key
      t.string :outcome
      t.bigint :event_count, null: false, default: 0
      t.timestamps
    end
    RecordingStudioLogs::Schema.summary_index(
      TABLE,
      %i[day root_recording_id resource_key action_key outcome],
      name: IDENTITY_INDEX
    )
    add_index TABLE, %i[root_recording_id day], name: "index_admin_audit_day_summaries_on_root_and_day"
  end

  def down
    drop_table TABLE if connection.data_source_exists?(TABLE)
  end
end
