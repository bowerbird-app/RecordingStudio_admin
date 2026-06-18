# frozen_string_literal: true

module AdminScreens
  class <%= resource_class_name %> < RecordingStudioAdmin::Resource
    key "<%= resource_key %>"
    section "<%= section_key %>"
    title "Manage <%= route_resource_name.humanize.downcase %>"
    subtitle "View and edit <%= route_resource_name.humanize.downcase %>"

<% if route_actions.include?("show") -%>
    action :show,
           text: "Show",
           icon: "eye",
           url: lambda { |row, context|
             record = record_for(row)
             context.controller.main_app.<%= namespace_name %>_<%= singular_name %>_path(record) if record
           },
           visible_if: ->(row, _context) { record_for(row).present? }

<% end -%>
<% if route_actions.include?("edit") -%>
    action :edit,
           text: "Edit",
           icon: "pencil-square",
           required_role: :admin,
           url: lambda { |row, context|
             record = record_for(row)
             context.controller.main_app.edit_<%= namespace_name %>_<%= singular_name %>_path(record) if record
           },
           visible_if: ->(row, _context) { record_for(row).present? }

<% end -%>
    def self.record_for(row)
      return row if row.is_a?(<%= model_class_name %>)
      return <%= model_class_name %>.find_by(id: row.id) if row.respond_to?(:id)

      nil
    end
  end
end