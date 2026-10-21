# frozen_string_literal: true

require "test_helper"

class LogsRegistrationTest < Minitest::Test
  def test_aggregatable_allowlist_omits_actor_and_request_fields
    allowlist = RecordingStudioAdmin::LogsRegistration::AGGREGATABLE.keys
    forbidden = RecordingStudioAdmin::LogsRegistration::FORBIDDEN_AGGREGATABLE

    assert_equal %i[root_recording_id resource_key action_key outcome], allowlist
    forbidden.each do |column|
      refute_includes allowlist, column
    end
  end

  def test_retention_registers_as_indefinite
    previous = RecordingStudioAdmin.configuration.logs_retention
    RecordingStudioAdmin.configuration.logs_retention = 90.days

    assert_equal :indefinite, RecordingStudioAdmin::LogsRegistration.resolved_retention
  ensure
    RecordingStudioAdmin.configuration.logs_retention = previous
  end

  def test_register_does_not_call_aggregate
    source = File.read(File.expand_path("../lib/recording_studio_admin/logs_registration.rb", __dir__))

    assert_includes source, "RecordingStudioLogs.register("
    refute_includes source, "RecordingStudioLogs.aggregate("
    refute_includes source, "register_audit_counts!"
    refute_includes source, "summaries_enabled?"
    refute_includes source, "audit_counts_definition"
  end

  def test_logs_upgrade_generator_keeps_the_existing_table
    root = File.expand_path("..", __dir__)
    generator = File.read(File.join(root, "lib/generators/recording_studio_admin/logs/logs_generator.rb"))
    templates = File.join(root, "lib/generators/recording_studio_admin/logs/templates")
    migration = File.read(File.join(templates, "db/migrate/add_root_recording_id_to_admin_audit_logs.rb"))

    assert_includes generator, "class LogsGenerator"
    refute_includes generator, "copy_summary_model"
    refute_includes generator, "create_admin_audit_day_summaries"
    assert_includes migration, "RecordingStudioLogs::Cutover.add_root_column"
    assert_includes migration, "recording_column: :access_recording_id"
    refute_includes migration, "Cutover.copy"
    refute_includes migration, "partitioned_log"
  end
end
