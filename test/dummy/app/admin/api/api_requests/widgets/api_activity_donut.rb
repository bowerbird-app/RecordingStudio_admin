# frozen_string_literal: true

module AdminScreens
  class ApiRequests
    widget :api_activity_donut do
      type :chart
      title "API status split (donut)"
      description "Request status distribution over the selected period."
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
      chart_type :donut
      series do |context|
        range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
        ApiRequest.where(created_at: range).group(:status).order(Arel.sql("COUNT(*) DESC")).count.values
      end
      chart_options do |context|
        range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
        labels = ApiRequest.where(created_at: range).group(:status).order(Arel.sql("COUNT(*) DESC")).count.keys
        {
          labels: labels.map(&:to_s),
          height: 220,
          legend: { position: "bottom" }
        }
      end
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "api_requests", preset_key: :this_week)
      end
    end
  end
end