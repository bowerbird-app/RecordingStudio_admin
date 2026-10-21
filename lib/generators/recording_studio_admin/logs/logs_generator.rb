# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioAdmin
  module Generators
    class LogsGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Adds RecordingStudioLogs columns and the admin audit day summary for existing hosts"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_summary_model
        template "app/models/admin_audit_day_summary.rb", "app/models/admin_audit_day_summary.rb"
      end

      def copy_migrations
        migration_template "db/migrate/add_root_recording_id_to_admin_audit_logs.rb",
                           "db/migrate/add_root_recording_id_to_admin_audit_logs.rb"
        migration_template "db/migrate/create_admin_audit_day_summaries.rb",
                           "db/migrate/create_admin_audit_day_summaries.rb"
      end
    end
  end
end
