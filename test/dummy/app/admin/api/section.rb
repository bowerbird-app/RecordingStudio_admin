# frozen_string_literal: true

module AdminScreens
  class ApiSection < RecordingStudioAdmin::Section
    key "api"
    icon :document_text
    title "API"
    subtitle "Monitor API traffic, failures, and common error classes"
    blast_radius :site

    link :requests, text: "View API requests", url: ->(context) { context.admin_screen_path("api_requests") }, style: :secondary
    link :errors, text: "View API errors", url: ->(context) { context.admin_screen_path("api_errors") }, style: :secondary
    link :most_common_errors,
         text: "View most common errors",
         url: ->(context) { context.admin_screen_path("most_common_errors") },
         style: :secondary

    widget "widgets.api_requests.api_activity",
           view_variant: :compact,
           params: { preset_key: :this_week }
    widget "widgets.api_errors.recent_failures",
           view_variant: :compact,
           params: { preset_key: :this_week }
        widget "widgets.most_common_errors.error_distribution_chart",
          view_variant: :compact,
          params: { preset_key: :this_week }
    widget "widgets.most_common_errors.error_distribution_chart", params: { preset_key: :this_week }
  end
end
