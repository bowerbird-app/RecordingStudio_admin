# frozen_string_literal: true

module AdminScreens
  class RootSection < RecordingStudioAdmin::Section
    key "root"
    icon :folder
    title "Admin section"
    subtitle "Monitor API traffic, users, jobs, and failures"
       blast_radius :site

    recordable "AdminSection",
               find_or_create_by: -> { { key: "root", name: "Admin section" } },
               parent: -> { AdminRoot.find_or_create_by!(name: "Admin") }

    link :api, text: "View API", url: ->(context) { context.admin_section_path("api") }, style: :secondary
    link :users, text: "View users", url: ->(context) { context.admin_section_path("users") }, style: :secondary
    link :jobs, text: "View jobs", url: ->(context) { context.admin_section_path("jobs") }, style: :secondary
    link :admin_activity_logs,
           text: "View admin activity logs",
           url: ->(context) { context.admin_section_path("admin_activity_logs") },
           style: :secondary

    widget "widgets.api_requests.api_activity",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity", params: { preset_key: :this_week }
    widget "widgets.api_errors.recent_failures",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.api_errors.recent_failures", params: { preset_key: :this_week }
    widget "widgets.most_common_errors.error_distribution_chart",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.most_common_errors.error_distribution_chart", params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_column",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_column", params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_donut",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_donut", params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_radar",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_radar", params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_gauge",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.api_requests.api_activity_gauge", params: { preset_key: :this_week }
    widget "widgets.user_activity.review_completion",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.user_activity.active_users", params: { preset_key: :this_week }
    widget "widgets.user_activity.most_recent_users",
           view_variant: :compact
    widget "widgets.user_activity.most_recent_users"
    widget "widgets.background_jobs.job_throughput",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.background_jobs.job_throughput", params: { preset_key: :this_week }
  end
end
