# frozen_string_literal: true

module AdminScreens
  class StatsSection < RecordingStudioAdmin::Section
    key "stats"
    icon :chart_bar
    title "Stats"
    subtitle "Track workspace content and recording activity"
    blast_radius :root

    link :stats,
         text: "View stats",
    url: ->(context) { context.admin_screen_path("workspace_stats") },
         style: :secondary

    widget "widgets.workspace_stats.total_items",
      view_variant: :compact,
      params: { preset_key: :this_week }
    widget "widgets.workspace_stats.total_pages",
      view_variant: :compact,
      params: { preset_key: :this_week }
    widget "widgets.workspace_stats.total_folders",
      view_variant: :compact,
      params: { preset_key: :this_week }
    widget "widgets.workspace_stats.total_items", params: { preset_key: :this_week }
    widget "widgets.workspace_stats.total_pages", params: { preset_key: :this_week }
    widget "widgets.workspace_stats.total_folders", params: { preset_key: :this_week }
    widget "widgets.workspace_stats.content_activity", params: { preset_key: :this_week }
  end
end
