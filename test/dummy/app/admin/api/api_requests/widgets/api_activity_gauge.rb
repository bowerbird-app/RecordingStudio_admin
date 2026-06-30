# frozen_string_literal: true

module AdminScreens
  class ApiRequests
    widget :api_activity_gauge do
      type :chart
      title "API success rate (gauge)"
      description "Percentage of successful API requests in the selected period."
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
        scope = ApiRequest.where(created_at: range)
        total = scope.count
        next 0 if total.zero?

        success_total = scope.where(status: 200...300).count
        ((success_total.to_f / total) * 100).round
      end
      change { |_context| AdminScreens::Base.period_change_label(ApiRequest.all) }
      chart_type :gauge
      series do |context|
        range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
        scope = ApiRequest.where(created_at: range)
        total = scope.count
        next [0] if total.zero?

        success_total = scope.where(status: 200...300).count
        [((success_total.to_f / total) * 100).round]
      end
      chart_options do
        {
          labels: ["Success rate"],
          height: 220,
          dataLabels: {
            formatter: "function (value) { return Math.round(value) + '%'; }"
          }
        }
      end
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "api_requests", preset_key: :this_week)
      end
    end
  end
end