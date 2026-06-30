# frozen_string_literal: true

class Admin::GeneratorsController < Admin::BaseController
  layout "flat_pack_sidebar"

  def index
    @generator_rows = [
      {
        name: "recording_studio_admin:install",
        command: "bin/rails generate recording_studio_admin:install",
        summary: "Installs the engine in a host app and sets up baseline routing/configuration.",
        routes: [
          "mount RecordingStudioAccessible::Engine, at: \"/admin/access\"",
          "recording_studio_admin_for :admin, at: \"/admin\""
        ],
        generated_files: [
          "config/initializers/recording_studio_admin.rb"
        ],
        outputs: [
          "Injects Tailwind @source lines for RecordingStudioAdmin and FlatPack when app/assets/tailwind/application.css exists"
        ]
      },
      {
        name: "recording_studio_admin:admin_root",
        command: "bin/rails generate recording_studio_admin:admin_root",
        summary: "Scaffolds a dummy admin root experience, admin audit storage, and enablement for the built-in Admin activity logs screen.",
        routes: [
          "namespace :admin do",
          "  get \"root\", to: \"root#show\"",
          "end"
        ],
        generated_files: [
          "app/models/admin_root.rb",
          "app/models/admin_audit_log.rb",
          "app/controllers/admin/base_controller.rb",
          "app/controllers/admin/root_controller.rb",
          "app/views/admin/root/show.html.erb",
          "app/views/layouts/admin.html.erb",
          "app/javascript/controllers/admin/root_search_controller.js",
          "db/migrate/create_admin_roots.rb",
          "db/migrate/create_admin_audit_logs.rb"
        ],
        outputs: [
          "Adds /admin/root route and renders the generated admin root page",
          "Enables the built-in admin_activity_logs section on AdminRoot"
        ]
      }
    ]
  end
end
