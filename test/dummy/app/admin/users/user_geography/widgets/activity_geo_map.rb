# frozen_string_literal: true

module AdminScreens
  UserGeographyActivityGeoMapWidget = RecordingStudioAdmin::Widget.new("widgets.user_geography.activity_geo_map") do
    type :chart
    title "User activity geography"
    description "User activity distribution by country for the selected period."
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
      UserActivity.where(created_at: range).count
    end
    change { |_context| AdminScreens::Base.period_change_label(UserActivity.all) }
    chart_type :geo
    series do |context|
      range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
      [ {
        name: "User activities",
        data: AdminScreens::UserGeography.geo_series(UserActivity.where(created_at: range))
      } ]
    end
    chart_options do
      {
        chart: { height: 260 },
        geo: { map: "world", key_field: "iso2" }
      }
    end
    link_to do |context|
      AdminScreens::Base.widget_link_path(context, screen_key: "user_geography", preset_key: :this_week)
    end
  end
end
