# frozen_string_literal: true

module AdminScreens
  class UserSignIns < Base
    key "user_sign_ins"
    icon :arrow_right_end_on_rectangle
    title "User sign-ins"
    subtitle "Track sign-in volume and recent access events"
    query { |_context| UserActivity.where(action: "signed_in") }
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :status, options: -> { UserActivity.where(action: "signed_in").distinct.order(:status).pluck(:status) }
  end
end