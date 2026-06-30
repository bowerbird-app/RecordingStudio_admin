# frozen_string_literal: true

module AdminScreens
  class MostCommonErrors
    table do
      filter :search, apply: lambda { |relation, value, _context|
        next relation unless value.present?

        relation.where("error_class ILIKE :q", q: AdminScreens::Base.safe_like(value))
      }
      default_sort :error_count, direction: :desc
      column :error_class, title: "Error class"
      column :error_count, title: "Count"
      action :view_api_errors,
        text: "View API errors",
        icon: "exclamation-triangle",
        url: ->(row, context) { "#{context.admin_screen_path("api_errors")}?#{ { search: row.error_class }.to_query }" }
      action :filter_breakdown,
        text: "Filter breakdown",
        icon: "funnel",
        url: ->(row, context) { "#{context.admin_screen_path("most_common_errors")}?#{ { search: row.error_class }.to_query }" }
      paginate per_page: 25
    end
  end
end