# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_admin/admin_root/admin_root_generator"
require "generators/recording_studio_admin/logs/logs_generator"

class LogsAdoptionGeneratorsTest < Minitest::Test
  def test_logs_generator_copies_root_migration_only
    with_temp_app do |dir|
      generator = RecordingStudioAdmin::Generators::LogsGenerator.new([], {}, destination_root: dir)
      generator.invoke_all

      migrations = Dir[File.join(dir, "db/migrate/*add_root_recording_id_to_admin_audit_logs.rb")]
      assert_equal 1, migrations.size
      assert_includes File.read(migrations.first), "RecordingStudioLogs::Cutover.add_root_column"
      refute File.exist?(File.join(dir, "app/models/admin_audit_day_summary.rb"))
      assert_empty Dir[File.join(dir, "db/migrate/*create_admin_audit_day_summaries.rb")]
    end
  end

  def test_admin_root_generator_copies_audit_logs_with_root_and_skips_summaries
    with_temp_app do |dir|
      generator = RecordingStudioAdmin::Generators::AdminRootGenerator.new([], {}, destination_root: dir)
      generator.invoke_all

      assert File.exist?(File.join(dir, "app/models/admin_audit_log.rb"))
      refute File.exist?(File.join(dir, "app/models/admin_audit_day_summary.rb"))
      audit_migrations = Dir[File.join(dir, "db/migrate/*create_admin_audit_logs.rb")]
      assert_equal 1, audit_migrations.size
      assert_includes File.read(audit_migrations.first), "t.uuid :root_recording_id"
      assert_empty Dir[File.join(dir, "db/migrate/*create_admin_audit_day_summaries.rb")]
    end
  end

  private

  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "config"))
      FileUtils.mkdir_p(File.join(dir, "db/migrate"))
      File.write(File.join(dir, "config/routes.rb"), "Rails.application.routes.draw do\nend\n")
      yield dir
    end
  end
end
