# frozen_string_literal: true

module AdminScreens
  class ApiRequests
    table do
      export "admin.api_requests", text: "Export"
      filter :search, apply: ->(relation, value, _context) { value.present? ? relation.where("path ILIKE ?", AdminScreens::Base.safe_like(value)) : relation }
      column :created_at
      column :method
      column :status, display: :badge, display_options: ->(_row, _context, value) do
        {
          text: value.to_s,
          size: :sm,
          style: case value.to_i
                 when 200..299 then :success
                 when 400..499 then :warning
                 when 500..599 then :danger
                 else :default
                 end
        }
      end
      column :path
      column :latency_ms,
             title: "Latency",
             tooltip: ->(row, _context) { "#{row.latency_ms}ms total request time" },
             header_tooltip: "Total request time in milliseconds"
      default_columns :created_at, :method, :status, :path
      action :filter_path,
        text: "Filter path",
        icon: "funnel",
        url: ->(row, context) { "#{context.admin_screen_path("api_requests")}?#{ { search: row.path }.to_query }" }
      action :view_errors,
        text: "View errors",
        icon: "exclamation-triangle",
        url: ->(row, context) { "#{context.admin_screen_path("api_errors")}?#{ { search: row.path }.to_query }" },
        visible_if: ->(row, _context) { row.status.to_i >= 400 }
      paginate per_page: 25, mode: :infinite
    end
  end
end
