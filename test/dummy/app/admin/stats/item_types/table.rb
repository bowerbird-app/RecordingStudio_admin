# frozen_string_literal: true

module AdminScreens
  class ItemTypes
    table do
      column :recordable_type,
             title: "Type",
             display: :badge,
             display_options: lambda { |_row, _context, value|
               { text: value, style: AdminScreens::WorkspaceStats.badge_style_for(value), size: :sm }
             }
      column :item_name,
             title: "Item",
             sortable: false,
             value: ->(row, _context) { AdminScreens::ItemTypes.item_label(row) }

      default_sort :recordable_type, direction: :asc
      paginate per_page: 25
    end
  end
end
