# frozen_string_literal: true

module AdminScreens
  class ApiRequests < Base
    key "api_requests"
    icon :document_text
    title "API requests"
    subtitle "Monitor API traffic, latency, and failures"
    allow_export required_role: :admin
    query { |_context| ApiRequest.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { ApiRequest.distinct.order(:status).pluck(:status) }

    widget "widgets.api_requests.api_activity"
    widget "widgets.api_requests.api_activity_column"
    widget "widgets.api_requests.api_activity_donut"
    widget "widgets.api_requests.api_activity_radar"
    widget "widgets.api_requests.api_activity_gauge"
    widget "widgets.api_requests.monthly_api_usage"

    summary do
      label "Total requests"
      change_good_when :up
    end
  end
end
