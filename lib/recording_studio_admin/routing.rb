# frozen_string_literal: true

module RecordingStudioAdmin
  module Routing
    def recording_studio_admin_for(name, at:, as: nil, **surface_options)
      RecordingStudioAdmin.configuration.surface(name, **surface_options, path: at)
      mount RecordingStudioAdmin::Engine, at: at, as: as || "recording_studio_admin_#{name}"
    end
  end
end
