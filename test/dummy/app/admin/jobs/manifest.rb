# frozen_string_literal: true

module AdminScreens
  module Jobs
    def self.register!
      RecordingStudioAdmin.register_screen(AdminScreens::BackgroundJobs)
      RecordingStudioAdmin.register_section(AdminScreens::JobsSection)
    end
  end
end