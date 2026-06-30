# frozen_string_literal: true

module AdminScreens
  module Stats
    def self.register!
      RecordingStudioAdmin.register_screen(AdminScreens::WorkspaceStats)
      RecordingStudioAdmin.register_section(AdminScreens::StatsSection)
    end
  end
end
