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

    def period_for(filter_key: :date_range, duration: nil, reference_time: current_time)
      return RecordingStudioAdmin::Period.from_duration(duration, reference_time: reference_time) if duration

      value = filter_value(filter_key)
      return unless value.respond_to?(:start_date) && value.respond_to?(:end_date)

      RecordingStudioAdmin::Period.from_date_range(
        start_date: value.start_date,
        end_date: value.end_date,
        preset_key: value.respond_to?(:preset_key) ? value.preset_key : nil,
        reference_date: reference_time.to_date
      )
    end

    def period_label(filter_key: :date_range, duration: nil, reference_time: current_time)
      period_for(filter_key: filter_key, duration: duration, reference_time: reference_time)&.label
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

    def current_time
      if defined?(Time) && Time.respond_to?(:zone) && Time.zone
        Time.zone.now
      else
        Time.now
      end
    end
  end
end
