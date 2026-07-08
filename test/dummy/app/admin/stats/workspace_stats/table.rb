# frozen_string_literal: true

module AdminScreens
  class WorkspaceStats
    table do
      filter :recordable_type, apply: lambda { |relation, value, _context|
        value.present? ? relation.where(recordable_type: value) : relation
      }, options: %w[Folder Page]

      column :created_at
      column :recordable_type,
             title: "Type",
             display: :badge,
             display_options: lambda { |_row, _context, value|
               { text: value, style: AdminScreens::WorkspaceStats.badge_style_for(value), size: :sm }
             }
      column :item_name,
             title: "Item",
             sortable: false,
             value: ->(row, _context) { AdminScreens::WorkspaceStats.recordable_label(row) }
      column :parent_name,
             title: "Parent",
             sortable: false,
             value: ->(row, _context) { AdminScreens::WorkspaceStats.parent_label(row) }

      default_sort :created_at, direction: :desc
      paginate per_page: 25
    end
  end
end
