# frozen_string_literal: true

require "test_helper"

class AdminAuditLogsRegistrationTest < ActiveSupport::TestCase
  include DummyAccessTestHelpers

  setup do
    @previous_flag = RecordingStudioAdmin.configuration.logs_summaries_enabled
    RecordingStudioAdmin.configuration.logs_summaries_enabled = false
    RecordingStudioAdmin::LogsRegistration.register!
    @admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    @recording = RecordingStudio.root_recording_for(@admin_root)
  end

  teardown do
    RecordingStudioAdmin.configuration.logs_summaries_enabled = @previous_flag
    RecordingStudioAdmin::LogsRegistration.register!
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

  test "registers a daily audit count aggregation without actor or request fields" do
    aggregation = RecordingStudioAdmin::LogsRegistration.audit_counts_definition

    assert_equal "admin/audit_counts", aggregation.name
    assert_equal %i[root_recording_id resource_key action_key outcome], aggregation.group_by
    assert_equal AdminAuditDaySummary, aggregation.summary_model
    RecordingStudioAdmin::LogsRegistration::FORBIDDEN_AGGREGATABLE.each do |column|
      refute_includes aggregation.group_by, column
    end
  end

  test "summaries stay off by default and activity logs keep the raw model" do
    refute RecordingStudioAdmin::LogsRegistration.summaries_enabled?
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

  test "rebuilding a UTC day writes summary rows that match the raw count" do
    RecordingStudioAdmin.configuration.logs_summaries_enabled = true
    day = Date.new(2026, 10, 14)
    create_audit_log!(
      event_id: "rebuild-a-#{SecureRandom.hex(4)}",
      occurred_at: Time.utc(2026, 10, 14, 9, 0, 0),
      resource_key: "users",
      action_key: "update",
      outcome: "performed"
    )
    create_audit_log!(
      event_id: "rebuild-b-#{SecureRandom.hex(4)}",
      occurred_at: Time.utc(2026, 10, 14, 18, 0, 0),
      resource_key: "users",
      action_key: "update",
      outcome: "performed"
    )
    create_audit_log!(
      event_id: "rebuild-c-#{SecureRandom.hex(4)}",
      occurred_at: Time.utc(2026, 10, 15, 1, 0, 0),
      resource_key: "users",
      action_key: "update",
      outcome: "performed"
    )

    RecordingStudioAdmin::Services::RebuildAdminAuditLogSummaries.call(day: day)

    rows = AdminAuditDaySummary.where(
      day: day,
      root_recording_id: @recording.id,
      resource_key: "users",
      action_key: "update",
      outcome: "performed"
    )
    assert_equal 1, rows.count
    assert_equal 2, rows.sole.event_count
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
