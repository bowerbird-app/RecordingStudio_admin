# frozen_string_literal: true

module AdminScreens
  module Root
    def self.register!
      RecordingStudioAdmin.register_section(AdminScreens::RootSection)
    end
  end
end