# frozen_string_literal: true

module AdminScreens
  module UsersArea
    def self.register!
      RecordingStudioAdmin.register_screen(AdminScreens::Users)
      RecordingStudioAdmin.register_screen(AdminScreens::UserActivityScreen)
      RecordingStudioAdmin.register_screen(AdminScreens::UserSignIns)
      RecordingStudioAdmin.register_screen(AdminScreens::UserReviews)
      RecordingStudioAdmin.register_screen(AdminScreens::UserInvitations)
      RecordingStudioAdmin.register_screen(AdminScreens::UserGeography)
      RecordingStudioAdmin.register_resource(AdminScreens::UsersResource)
      RecordingStudioAdmin.register_section(AdminScreens::UsersSection)
    end
  end
end