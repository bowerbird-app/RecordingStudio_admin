# frozen_string_literal: true

require "rails/generators"
require "rails/generators/active_record"

module RecordingStudioAdmin
  module Generators
    class AdminRootGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def copy_model
        template "app/models/admin_root.rb", "app/models/admin_root.rb"
        template "app/models/admin_audit_log.rb", "app/models/admin_audit_log.rb"
        template "app/models/admin_audit_day_summary.rb", "app/models/admin_audit_day_summary.rb"
      end

      def copy_controllers
        template "app/controllers/admin/base_controller.rb", "app/controllers/admin/base_controller.rb"
        template "app/controllers/admin/root_controller.rb", "app/controllers/admin/root_controller.rb"
      end

      def copy_views
        template "app/views/admin/root/show.html.erb", "app/views/admin/root/show.html.erb"
        template "app/views/admin/root/_search_results.html.erb", "app/views/admin/root/_search_results.html.erb"
        template "app/views/layouts/admin.html.erb", "app/views/layouts/admin.html.erb"
      end

      def copy_javascript
        template "app/javascript/controllers/admin/root_search_controller.js",
                 "app/javascript/controllers/admin/root_search_controller.js"
      end

      def copy_migration
        migration_template "db/migrate/create_admin_roots.rb", "db/migrate/create_admin_roots.rb"
        migration_template "db/migrate/create_admin_audit_logs.rb", "db/migrate/create_admin_audit_logs.rb"
        migration_template "db/migrate/create_admin_audit_day_summaries.rb",
                           "db/migrate/create_admin_audit_day_summaries.rb"
      end

      def add_route
        route %(namespace :admin do\n    get "root", to: "root#show"\n  end)
      end
    end
  end
end
