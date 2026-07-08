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
      RecordingStudioAdmin.register_widget(AdminScreens::UserActivityActiveUsersWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UserActivityMostRecentUsersWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UserActivityReviewCompletionWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UserActivityTotalActivitiesWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UserGeographyActivityGeoMapWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UserInvitationsRecentInvitesWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UserReviewsReviewVolumeWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UserSignInsSignInActivityWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UsersActiveUsersWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UsersMostRecentUsersWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::UsersReviewCompletionWidget)
      RecordingStudioAdmin.register_section(AdminScreens::UsersSection)
    end
  end
end
