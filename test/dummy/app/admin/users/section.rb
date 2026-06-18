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
    widget "user_sign_ins.widgets.sign_in_activity",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "user_reviews.widgets.review_volume",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "user_activity.widgets.review_completion", params: { preset_key: :this_week }
    widget "user_activity.widgets.most_recent_users"
    widget "user_geography.widgets.activity_geo_map", params: { preset_key: :this_week }
    widget "user_invitations.widgets.recent_invites"
  end
end