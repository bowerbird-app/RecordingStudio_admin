# frozen_string_literal: true

module AdminScreens
  class WorkspaceStats
    widget :content_activity do
      type :chart
      title "Content activity"
      description "Recent folder and page creation for the active workspace."
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
        AdminScreens::WorkspaceStats.recordings_for(context, time_range: range).count
      end
      change do |context|
        AdminScreens::Base.period_change_label(AdminScreens::WorkspaceStats.recordings_scope(context))
      end
      chart_type :bar
      series do |context|
        range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
        [ {
          name: "Content activity",
          data: AdminScreens::Base.date_series(
            AdminScreens::WorkspaceStats.recordings_for(context, time_range: range).reorder(nil),
            bucket: context.widget_group_by(default: :day)
          )
        } ]
      end
      chart_options { { height: 220 } }
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "workspace_stats", preset_key: :this_week)
      end
    end
  end
end