# frozen_string_literal: true

module AdminScreens
  class UserReviews < Base
    key "user_reviews"
    icon :clipboard_document_check
    title "User reviews"
    subtitle "Inspect user activity that still needs review"
    query { |_context| UserActivity.where(status: "review") }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :action, options: -> { UserActivity.where(status: "review").distinct.order(:action).pluck(:action) }
  end
end