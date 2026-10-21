# frozen_string_literal: true

require "test_helper"

class AdminAuditLogsRegistrationTest < ActiveSupport::TestCase
  include DummyAccessTestHelpers

  setup do
    RecordingStudioAdmin::LogsRegistration.register!
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @recording = RecordingStudio.root_recording_for(@admin_root)
  end

  test "registers the existing admin audit log as an unpartitioned indefinite Logs source" do
    log = RecordingStudioLogs.registry.log_for(RecordingStudioAdmin::LogsRegistration.source_model_name)

    assert log
    assert_equal :occurred_at, log.timestamp_column
    assert_nil log.partition_interval
    assert_equal :root_recording_id, log.root_column
    assert_predicate log, :indefinite?
    assert_equal "admin_audit_logs", AdminAuditLog.table_name
    assert_includes AdminAuditLog.column_names, "root_recording_id"
    refute_includes connection_table_options, "PARTITION BY"
  end

  test "does not register a daily audit count aggregation" do
    aggregations = RecordingStudioLogs.registry.aggregations_for(
      RecordingStudioLogs.registry.log_for(RecordingStudioAdmin::LogsRegistration.source_model_name)
    )

    assert_empty aggregations
    assert_equal AdminAuditLog, RecordingStudioAdmin::AdminActivityLogsScreen.audit_log_model
  end

  test "new audit rows stamp the access recording root" do
    log = create_audit_log!(event_id: "stamp-root-#{SecureRandom.hex(4)}")

    assert_equal @recording.id, log.access_recording_id
    assert_equal @recording.id, log.root_recording_id
  end

  test "in-place backfill copies root_recording_id from the access recording" do
    log = create_audit_log!(event_id: "backfill-root-#{SecureRandom.hex(4)}")
    log.update_column(:root_recording_id, nil)

    RecordingStudioLogs::Cutover.backfill_root(
      :admin_audit_logs,
      recording_column: :access_recording_id
    )

    assert_equal @recording.id, log.reload.root_recording_id
  end

  private

  def create_audit_log!(event_id:, occurred_at: Time.current, resource_key: "users", action_key: "update",
                        outcome: "performed")
    AdminAuditLog.create!(
      event_id: event_id,
      resource_key: resource_key,
      action_key: action_key,
      outcome: outcome,
      access_recording_id: @recording.id,
      occurred_at: occurred_at,
      metadata: {}
    )
  end

  def connection_table_options
    result = AdminAuditLog.connection.select_one(<<~SQL.squish)
      SELECT relkind, relispartition
      FROM pg_class
      WHERE relname = 'admin_audit_logs'
    SQL
    result.to_h.inspect
  end
end
