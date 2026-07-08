# frozen_string_literal: true

module AdminScreens
  class ApiErrors
    table do
      filter :search, apply: lambda { |relation, value, _context|
        next relation unless value.present?

        q = AdminScreens::Base.safe_like(value)
        relation.where("message ILIKE :q OR path ILIKE :q OR error_class ILIKE :q", q: q)
      }
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
