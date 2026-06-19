# frozen_string_literal: true

module AdminScreens
  class ApiRequests
    widget :api_activity_column do
      type :chart
      title "API activity (column)"
      description "Seven-day request volume rendered as vertical columns."
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
      chart_type :column
      series do
        range = _1.widget_time_range || AdminScreens::Base.widget_preset_range(_1, preset_key: :this_week)
        [ {
          name: "API activity",
          data: AdminScreens::Base.date_series(ApiRequest.where(created_at: range), bucket: _1.widget_group_by(default: :day))
        } ]
      end
      chart_options { { height: 220 } }
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "api_requests", preset_key: :this_week)
      end
    end
  end
end