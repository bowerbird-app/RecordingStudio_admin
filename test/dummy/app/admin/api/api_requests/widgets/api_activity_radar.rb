# frozen_string_literal: true

module AdminScreens
  ApiRequestsApiActivityRadarWidget = RecordingStudioAdmin::Widget.new("widgets.api_requests.api_activity_radar") do
    type :chart
    title "API status spread (radar)"
    description "Status-code mix plotted as a radar chart for fast anomaly scanning."
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
      ApiRequest.where(created_at: range).count
    end
    change { |_context| AdminScreens::Base.period_change_label(ApiRequest.all) }
    chart_type :radar
    series do |context|
      range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
      status_counts = ApiRequest.where(created_at: range).group(:status).order(Arel.sql("COUNT(*) DESC")).count.first(6)

      [ {
        name: "Requests",
        data: status_counts.map { |_status, count| count }
      } ]
    end
    chart_options do |context|
      range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
      status_counts = ApiRequest.where(created_at: range).group(:status).order(Arel.sql("COUNT(*) DESC")).count.first(6)

      {
        xaxis: {
          categories: status_counts.map { |status, _count| status.to_s }
        },
        height: 220
      }
    end
    link_to do |context|
      AdminScreens::Base.widget_link_path(context, screen_key: "api_requests", preset_key: :this_week)
    end
  end
end
