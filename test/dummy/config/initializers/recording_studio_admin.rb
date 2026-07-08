# frozen_string_literal: true

# Resolve the access recording that gates both the mounted engine and the host-app admin root page.
RecordingStudioAdmin.configure do |config|
  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio::Recording.find_by(recordable: admin_root, trashed_at: nil)
  end
  config.site_admin_recording_resolver = config.access_recording_resolver
  config.admin_action_auditor = lambda do |event|
    AdminAuditLog.record_admin_action!(event) if defined?(AdminAuditLog) && AdminAuditLog.table_exists?
  end

  config.surface :stats do |surface|
    surface.access_recording_resolver = ->(context) { context.controller.current_root_recording }
    surface.allow_export_default_role = :admin
  end
end

Rails.application.config.to_prepare do
  load Rails.root.join("app/admin/manifest.rb")

  AdminScreens.load!
  AdminScreens::Root.register!
  AdminScreens::Api.register!
  AdminScreens::UsersArea.register!
  AdminScreens::Jobs.register!
  AdminScreens::Stats.register!
end
