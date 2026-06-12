# frozen_string_literal: true

module RecordingStudioAdmin
  class Context
    attr_reader :params, :current_actor, :controller, :routes, :view_context
    attr_accessor :query_result, :table_result

    def initialize(params: {}, current_actor: nil, controller: nil, routes: nil, view_context: nil)
      @params = params || {}
      @current_actor = current_actor
      @controller = controller
      @routes = routes || controller
      @view_context = view_context
      @filter_values = {}
    end

    def set_filter_value(key, value)
      @filter_values[key.to_sym] = value
    end

    def filter_value(key)
      @filter_values[key.to_sym]
    end

    def admin_screen_path(key)
      return routes.screen_path(key) if routes.respond_to?(:screen_path)
      return routes.recording_studio_admin.screen_path(key) if routes.respond_to?(:recording_studio_admin)

      "#{default_mount_path}/screens/#{key}"
    end

    def admin_section_path(key)
      return routes.section_path(key) if routes.respond_to?(:section_path)
      return routes.recording_studio_admin.section_path(key) if routes.respond_to?(:recording_studio_admin)

      "#{default_mount_path}/sections/#{key}"
    end

    private

    def default_mount_path
      RecordingStudioAdmin.configuration.default_mount_path.to_s.chomp("/")
    end
  end
end
