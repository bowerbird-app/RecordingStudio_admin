# frozen_string_literal: true

# The access recording gates every admin screen. The mounted admin uses the admin root.
RecordingStudioAdmin.configure do |config|
  config.access_recording_resolver = lambda do |context|
    RecordingStudioAccessible.admin_root(context: context)
  end
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
