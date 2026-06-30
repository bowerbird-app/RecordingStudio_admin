class Workspace < ApplicationRecord
  include RecordingStudioAccessible::AllowsAccessibleChildren
  include RecordingStudioAdmin::AllowsAdminSections

  recording_studio_recordable label: "Workspace", root: true
  recording_studio_accessible_children :access

  recording_studio_admin_sections do
    section :stats
  end
end
