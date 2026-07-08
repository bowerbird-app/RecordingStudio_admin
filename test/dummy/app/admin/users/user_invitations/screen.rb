# frozen_string_literal: true

module AdminScreens
  class UserInvitations < Base
    key "user_invitations"
    icon :user_plus
    title "User invitations"
    subtitle "Monitor invitation activity and newly invited users"
    query { |_context| UserActivity.where(action: "invited_user") }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { UserActivity.where(action: "invited_user").distinct.order(:status).pluck(:status) }
  end
end
