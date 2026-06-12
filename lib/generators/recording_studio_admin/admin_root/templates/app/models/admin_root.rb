# frozen_string_literal: true

class AdminRoot < ApplicationRecord
  include RecordingStudio::Recordable
  include RecordingStudioAccessible::AllowsAccessibleChildren

  recording_studio_recordable label: "Admin", root: true
  recording_studio_accessible_children :access
end
