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

    widget "widgets.user_activity.active_users",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.user_activity.active_users", params: { preset_key: :this_week }
    widget "widgets.user_sign_ins.sign_in_activity",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.user_sign_ins.sign_in_activity", params: { preset_key: :this_week }
    widget "widgets.user_reviews.review_volume",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.user_reviews.review_volume", params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_column",
           view_variant: :compact,
           title: "User activity (compact column)",
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_column",
           title: "User activity (column)",
           params: { preset_key: :this_week }
    widget "widgets.most_common_errors.error_distribution_chart",
           view_variant: :compact,
           title: "User error distribution (compact pie)",
           params: { preset_key: :this_week }
    widget "widgets.most_common_errors.error_distribution_chart",
           title: "User error distribution (pie)",
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_donut",
           view_variant: :compact,
           title: "User status split (compact donut)",
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_donut",
           title: "User status split (donut)",
           params: { preset_key: :this_week }
    widget "widgets.user_activity.total_activities",
           view_variant: :compact,
           title: "Total items (compact number)",
           params: { preset_key: :this_week }
    widget "widgets.user_activity.review_completion",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.user_activity.most_recent_users",
           view_variant: :compact
    widget "widgets.user_activity.review_completion", params: { preset_key: :this_week }
    widget "widgets.user_activity.most_recent_users"
    widget "widgets.user_geography.activity_geo_map",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.user_geography.activity_geo_map", params: { preset_key: :this_week }
  end
end
