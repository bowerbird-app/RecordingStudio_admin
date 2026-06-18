# frozen_string_literal: true

module RecordingStudioAdmin
  class AdminActivityLogsSection < RecordingStudioAdmin::Section
    key "admin_activity_logs"
    icon :clipboard_document_list
    title "Admin activity logs"
    subtitle "Audit admin CRUD changes and resource actions"
    blast_radius :site

    link :admin_activity_logs,
         text: "View admin activity logs",
         url: ->(context) { context.admin_screen_path("admin_activity_logs") },
         style: :secondary

    widget "admin_activity_logs.widgets.activity_overview",
           view_variant: :compact,
           params: { preset_key: :this_week }
  end
end