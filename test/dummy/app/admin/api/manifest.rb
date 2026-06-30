# frozen_string_literal: true

module AdminScreens
  module Api
    def self.register!
      RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
      RecordingStudioAdmin.register_screen(AdminScreens::ApiErrors)
      RecordingStudioAdmin.register_screen(AdminScreens::MostCommonErrors)
      RecordingStudioAdmin.register_section(AdminScreens::ApiSection)
    end
  end
end