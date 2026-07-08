# frozen_string_literal: true

module AdminScreens
  class Users < Base
    key "users"
    icon :user_group
    title "Users"
    subtitle "Manage user accounts"
    allow_export required_role: :view
    query { |_context| User.order(:email) }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day

    widget "widgets.users.active_users"
    widget "widgets.users.review_completion"
    widget "widgets.users.most_recent_users"

    summary do
      label "Total users"
      change_good_when :up
    end
  end
end
