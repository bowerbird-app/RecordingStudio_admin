# frozen_string_literal: true

module AdminScreens
  class MostCommonErrors
    widget :error_distribution_chart do
      type :chart
      title "Most common errors"
      description "Top API error classes over the last seven days."
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
        ApiError.where(created_at: range).count
      end
      change { |_context| AdminScreens::Base.period_change_label(ApiError.all) }
      chart_type :pie
      series do |context|
        range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
        AdminScreens::MostCommonErrors.top_error_breakdown(ApiError.where(created_at: range)).map do |entry|
          entry[:value]
        end
      end
      chart_options do |context|
        range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
        breakdown = AdminScreens::MostCommonErrors.top_error_breakdown(ApiError.where(created_at: range))
        {
          labels: breakdown.map { |entry| entry[:label] },
          height: 220,
          legend: { position: "bottom" }
        }
      end
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "most_common_errors", preset_key: :this_week)
      end
    end
  end
end