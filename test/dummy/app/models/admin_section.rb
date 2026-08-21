# frozen_string_literal: true

class AdminSection < ApplicationRecord
  include RecordingStudio::Recordable

  recording_studio_recordable label: "Admin section", root: false, allowed_parent_types: [ "AdminRoot" ]
  RecordingStudio.enable_capability(:accessible, on: self)
end
