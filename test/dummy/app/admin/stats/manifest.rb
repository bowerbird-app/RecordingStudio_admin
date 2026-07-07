# frozen_string_literal: true

module AdminScreens
  module Stats
    def self.register!
      RecordingStudioAdmin.register_screen(AdminScreens::WorkspaceStats)
      RecordingStudioAdmin.register_widget(AdminScreens::WorkspaceStatsContentActivityWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::WorkspaceStatsTotalFoldersWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::WorkspaceStatsTotalItemsWidget)
      RecordingStudioAdmin.register_widget(AdminScreens::WorkspaceStatsTotalPagesWidget)
      RecordingStudioAdmin.register_section(AdminScreens::StatsSection)
    end
  end
end
