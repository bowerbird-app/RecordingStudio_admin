class AdminRoot < ApplicationRecord
  include RecordingStudio::Recordable
  include RecordingStudioAccessible::AllowsAccessibleChildren
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  if defined?(RecordingStudio::Exportable::Capabilities::Exportable)
    RecordingStudio::Exportable::Capabilities::Exportable.enabled(
      export_keys: ["admin.api_requests"],
      required_role: :admin,
      max_rows: 50_000,
      formats: [:csv]
    )
  end
  recording_studio_accessible_children :access
  recording_studio_admin_sections do
    section :root
    section :api
    section :users
    section :jobs
    section :admin_activity_logs
  end
end
