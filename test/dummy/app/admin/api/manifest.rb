# frozen_string_literal: true

module AdminScreens
  module Api
    def self.register!
      RecordingStudioAdmin.register_screen(AdminScreens::ApiRequests)
      RecordingStudioAdmin.register_screen(AdminScreens::ApiErrors)
      RecordingStudioAdmin.register_screen(AdminScreens::MostCommonErrors)
      RecordingStudioAdmin.register_widget(AdminScreens::ApiErrorsRecentFailuresWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::ApiRequestsApiActivityWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::ApiRequestsApiActivityColumnWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::ApiRequestsApiActivityDonutWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::ApiRequestsApiActivityGaugeWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::ApiRequestsApiActivityRadarWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::ApiRequestsMonthlyApiUsageWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::MostCommonErrorsErrorDistributionChartWidget)
      RecordingStudioAdmin.register_section(AdminScreens::ApiSection)
    end
  end
end