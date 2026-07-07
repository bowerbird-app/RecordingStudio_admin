# frozen_string_literal: true

module AdminScreens
  WorkspaceStatsTotalPagesWidget = RecordingStudioAdmin::Widget.new("widgets.workspace_stats.total_pages") do
    title "Pages"
    description "Workspace pages created during the selected period."
    metadata do |context|
      {
        period_label: AdminScreens::Base.widget_preset_label(
          context,
          preset_key: :this_week,
          fallback: "This week"
        )
      }
    end
    value do |context|
      range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
      AdminScreens::WorkspaceStats.recordings_for(context, recordable_type: "Page", time_range: range).count
    end
    change do |context|
      AdminScreens::Base.period_change_label(
        AdminScreens::WorkspaceStats.recordings_scope(context).where(recordable_type: "Page")
      )
    end
    link_to do |context|
      AdminScreens::Base.widget_link_path(context, screen_key: "workspace_stats", preset_key: :this_week)
    end
  end
end
