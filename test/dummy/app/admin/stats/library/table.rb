# frozen_string_literal: true

module AdminScreens
  class Library
    table do
      column :name,
             title: "Name",
             sortable: false,
             value: ->(row, _context) { AdminScreens::Library.item_name(row) }
      column :recordable_type, title: "Kind"
      column :created_at, title: "Added"

      default_sort :created_at, direction: :desc
      paginate per_page: 25
    end

    class << self
      def item_name(recording)
        recordable = recording.recordable
        return recordable.title if recordable.respond_to?(:title) && recordable.title.present?
        return recordable.name if recordable.respond_to?(:name) && recordable.name.present?

        "Untitled"
      end
    end
  end
end
