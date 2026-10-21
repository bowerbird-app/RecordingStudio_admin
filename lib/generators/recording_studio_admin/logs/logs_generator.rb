# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioAdmin
  module Generators
    class LogsGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      desc "Adds RecordingStudioLogs root_recording_id to existing admin_audit_logs"

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_migrations
        migration_template "db/migrate/add_root_recording_id_to_admin_audit_logs.rb",
                           "db/migrate/add_root_recording_id_to_admin_audit_logs.rb"
      end
    end
  end
end
