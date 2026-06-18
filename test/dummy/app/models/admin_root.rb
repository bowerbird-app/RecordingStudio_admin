class AdminRoot < ApplicationRecord
  include RecordingStudio::Recordable
  include RecordingStudioAccessible::AllowsAccessibleChildren
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Admin", root: true
  recording_studio_accessible_children :access
  recording_studio_admin_sections do
    section :root
    section :api
    section :users
    section :jobs
    section :admin_activity_logs
  end
end
