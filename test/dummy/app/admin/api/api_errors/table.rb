# frozen_string_literal: true

module AdminScreens
  class ApiErrors
    table do
      filter :search, apply: RecordingStudioAdmin::Filters::Ilike.on(
        :message,
        :path,
        :error_class
      )
      column :created_at
      column :error_class
      column :status
      column :path
      column :message, sortable: false
      action :view_requests,
        text: "View requests",
        icon: "magnifying-glass",
        url: ->(row, context) { "#{context.admin_screen_path("api_requests")}?#{ { search: row.path }.to_query }" }
      action :similar_errors,
        text: "Similar errors",
        icon: "funnel",
        url: ->(row, context) { "#{context.admin_screen_path("api_errors")}?#{ { search: row.error_class }.to_query }" }
      paginate per_page: 25
    end
  end
end
