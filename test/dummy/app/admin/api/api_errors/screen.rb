# frozen_string_literal: true

module AdminScreens
  class ApiErrors < Base
    key "api_errors"
    icon :exclamation_triangle
    title "API errors"
    subtitle "Review API failures by class and status"
    query { |_context| ApiError.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day

    widget "widgets.api_errors.recent_failures"

    summary do
      label "Total errors"
      change_good_when :down
    end
  end
end