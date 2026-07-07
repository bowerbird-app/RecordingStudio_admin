# frozen_string_literal: true

module AdminScreens
  ApiRequestsMonthlyApiUsageWidget = RecordingStudioAdmin::Widget.new("widgets.api_requests.monthly_api_usage") do
    type :progress
    title "Monthly API usage"
    subtitle "Requests used against the monthly plan"
    description "Current calendar-month API usage against an example monthly quota."
    metadata do
      monthly_quota = 10_000
      current_usage = ApiRequest.where(created_at: Time.current.beginning_of_month..Time.current).count

      {
        period_label: Time.current.strftime("%B %Y"),
        progress_value: current_usage,
        progress_max: monthly_quota,
        progress_label: "#{current_usage} / #{monthly_quota} requests",
        progress_variant: case current_usage.to_f / monthly_quota
                          when 0.0...0.75 then :success
                          when 0.75...0.9 then :warning
                          else :danger
                          end
      }
    end
    link_to do |context|
      AdminScreens::Base.widget_link_path(context, screen_key: "api_requests", preset_key: :this_week)
    end
  end
end
