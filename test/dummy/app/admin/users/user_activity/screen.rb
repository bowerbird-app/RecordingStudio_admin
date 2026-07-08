# frozen_string_literal: true

module AdminScreens
  class UserActivityScreen < Base
    key "user_activity"
    icon :user_circle
    title "User activity"
    subtitle "Review user activity and access signals"
    query { |_context| UserActivity.all }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { UserActivity.distinct.order(:status).pluck(:status) }

    widget "widgets.user_activity.active_users"
    widget "widgets.user_activity.total_activities"
    widget "widgets.user_activity.review_completion"
    widget "widgets.user_activity.most_recent_users"

    summary do
      label "Total activities"
      change_good_when :up
    end
  end
end
