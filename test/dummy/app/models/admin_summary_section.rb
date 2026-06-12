class AdminSummarySection < ApplicationRecord
  include RecordingStudio::Recordable
  include RecordingStudioAccessible::AllowsAccessibleChildren

  recording_studio_recordable label: "Admin summary", root: false, allowed_parent_types: [ "AdminRoot" ]
  recording_studio_accessible_children :access
end
