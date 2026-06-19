# frozen_string_literal: true

module AdminScreens
  class UsersSection < RecordingStudioAdmin::Section
    key "users"
    icon :user_group
    title "Users"
    subtitle "Manage users and review access activity"
    blast_radius :site

    link :users, text: "View users", url: ->(context) { context.admin_screen_path("users") }, style: :secondary
    link :activity, text: "View user activity", url: ->(context) { context.admin_screen_path("user_activity") }, style: :secondary
    link :sign_ins, text: "View user sign-ins", url: ->(context) { context.admin_screen_path("user_sign_ins") }, style: :secondary
    link :reviews, text: "View review queue", url: ->(context) { context.admin_screen_path("user_reviews") }, style: :secondary
    link :invitations, text: "View invitations", url: ->(context) { context.admin_screen_path("user_invitations") }, style: :secondary
    link :geography, text: "View user geography", url: ->(context) { context.admin_screen_path("user_geography") }, style: :secondary

    widget "user_activity.widgets.active_users",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "user_activity.widgets.active_users", params: { preset_key: :this_week }
    widget "user_sign_ins.widgets.sign_in_activity",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "user_sign_ins.widgets.sign_in_activity", params: { preset_key: :this_week }
    widget "user_reviews.widgets.review_volume",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "user_reviews.widgets.review_volume", params: { preset_key: :this_week }
    widget "api_requests.widgets.api_activity_column",
           view_variant: :compact,
           title: "User activity (compact column)",
           params: { preset_key: :this_week }
    widget "api_requests.widgets.api_activity_column",
           title: "User activity (column)",
           params: { preset_key: :this_week }
    widget "most_common_errors.widgets.error_distribution_chart",
           view_variant: :compact,
           title: "User error distribution (compact pie)",
           params: { preset_key: :this_week }
    widget "most_common_errors.widgets.error_distribution_chart",
           title: "User error distribution (pie)",
           params: { preset_key: :this_week }
    widget "api_requests.widgets.api_activity_donut",
           view_variant: :compact,
           title: "User status split (compact donut)",
           params: { preset_key: :this_week }
    widget "api_requests.widgets.api_activity_donut",
           title: "User status split (donut)",
           params: { preset_key: :this_week }
    widget "user_activity.widgets.total_activities",
           view_variant: :compact,
           title: "Total items (compact number)",
           params: { preset_key: :this_week }
    widget "user_activity.widgets.review_completion",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "user_activity.widgets.most_recent_users",
           view_variant: :compact
    widget "user_activity.widgets.review_completion", params: { preset_key: :this_week }
    widget "user_activity.widgets.most_recent_users"
    widget "user_geography.widgets.activity_geo_map",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "user_geography.widgets.activity_geo_map", params: { preset_key: :this_week }
  end
end