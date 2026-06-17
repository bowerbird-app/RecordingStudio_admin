# frozen_string_literal: true

module RecordingStudioAdmin
  class Context
    attr_reader :params, :current_actor, :controller, :routes, :view_context
    attr_accessor :query_result, :table_result

    def initialize(params: {}, current_actor: nil, controller: nil, routes: nil, view_context: nil, filter_values: nil,
                   widget_params: nil, query_result: nil, table_result: nil)
      @params = params || {}
      @current_actor = current_actor
      @controller = controller
      @routes = routes || controller
      @view_context = view_context
      @filter_values = (filter_values || {}).dup
      @widget_params = normalize_widget_params(widget_params)
      @query_result = query_result
      @table_result = table_result
    end

    def set_filter_value(key, value)
      @filter_values[key.to_sym] = value
    end

    def filter_value(key)
      @filter_values[key.to_sym]
    end

    def with_widget_params(widget_params)
      merged_widget_params = @widget_params.merge(normalize_widget_params(widget_params))

      self.class.new(
        params: params,
        current_actor: current_actor,
        controller: controller,
        routes: routes,
        view_context: view_context,
        filter_values: @filter_values,
        widget_params: merged_widget_params,
        query_result: query_result,
        table_result: table_result
      )
    end

    def widget_param(key, default: nil)
      @widget_params.fetch(key.to_sym, default)
    end

    def widget_group_by(default: :day)
      (widget_param(:group_by, default: default) || default).to_sym
    end

    def widget_time_range(filter_key: :date_range, default_duration: nil, default_preset_key: nil,
                          reference_time: current_time)
      explicit_range = widget_param(:time_range) || widget_param(:range)
      return explicit_range if explicit_range

      duration = widget_param(:duration) || default_duration
      return (reference_time - duration)..reference_time if duration

      period = widget_period(
        filter_key: filter_key,
        default_duration: nil,
        default_preset_key: default_preset_key,
        reference_time: reference_time
      )
      return unless period&.start_date && period.end_date

      period.start_date.beginning_of_day..period.end_date.end_of_day
    end

    def widget_period_label(filter_key: :date_range, default_duration: nil, default_preset_key: nil,
                            reference_time: current_time)
      widget_period(
        filter_key: filter_key,
        default_duration: default_duration,
        default_preset_key: default_preset_key,
        reference_time: reference_time
      )&.label
    end

    def widget_filter_params(filter_key: :date_range, start_param: :start_date, end_param: :end_date,
                             preset_param: :date_range_preset, default_duration: nil, default_preset_key: nil,
                             reference_time: current_time)
      period = widget_period(
        filter_key: filter_key,
        default_duration: default_duration,
        default_preset_key: default_preset_key,
        reference_time: reference_time
      )
      return {} unless period&.start_date && period.end_date

      params = {
        start_param.to_sym => period.start_date.iso8601,
        end_param.to_sym => period.end_date.iso8601
      }
      params[preset_param.to_sym] = period.preset_key if preset_param && period.preset_key
      params
    end

    def widget_period(filter_key: :date_range, default_duration: nil, default_preset_key: nil,
                      reference_time: current_time)
      widget_duration = widget_param(:duration)
      widget_preset_key = widget_param(:preset_key)
      if widget_duration || widget_preset_key
        explicit_period = period_for(
          duration: widget_duration,
          preset_key: widget_preset_key,
          reference_time: reference_time
        )
        return explicit_period if explicit_period
      end

      return period_for(duration: default_duration, reference_time: reference_time) if default_duration
      return period_for(preset_key: default_preset_key, reference_time: reference_time) if default_preset_key

      period_for(filter_key: filter_key, reference_time: reference_time)
    end

    def period_for(filter_key: :date_range, duration: nil, preset_key: nil, reference_time: current_time)
      return RecordingStudioAdmin::Period.from_duration(duration, reference_time: reference_time) if duration

      if preset_key
        return RecordingStudioAdmin::Period.from_preset_key(preset_key,
                                                            reference_date: reference_time.to_date)
      end

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

    def admin_sections_path
      return routes.sections_path if routes.respond_to?(:sections_path)
      return routes.recording_studio_admin.sections_path if routes.respond_to?(:recording_studio_admin)

      "#{default_mount_path}/sections"
    end

    def available_admin_sections(recording: :__recording_studio_admin_default__, placement: :all)
      effective_recording = if recording == :__recording_studio_admin_default__
                              access_recording
                            else
                              recording
                            end

      RecordingStudioAdmin.available_sections(context: self, recording: effective_recording, placement: placement)
    end

    def available_admin_items(recording: :__recording_studio_admin_default__, placement: :all, parent: nil,
                              include: %i[sections screens])
      effective_recording = if recording == :__recording_studio_admin_default__
                              access_recording
                            else
                              recording
                            end

      RecordingStudioAdmin.available_admin_items(
        context: self,
        recording: effective_recording,
        placement: placement,
        parent: parent,
        include: include
      )
    end

    def access_recording
      resolver = RecordingStudioAdmin.configuration.access_recording_resolver
      resolved_recording = resolve_callable(resolver) if resolver
      return resolved_recording if resolved_recording

      method_name = RecordingStudioAdmin.configuration.access_recording_method
      return unless method_name && controller.respond_to?(method_name, true)

      controller.send(method_name)
    end

    def access_recordable
      access_recording&.recordable
    end

    def root_recording
      recording = access_recording
      return unless recording
      return recording.root_recording if recording.respond_to?(:root_recording) && recording.root_recording

      RecordingStudio.root_recording_or_self(recording)
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

    def resolve_callable(callable)
      arity = callable.arity
      case arity
      when 0 then callable.call
      when 1, -1 then callable.call(self)
      else callable.call(self, controller)
      end
    end

    def filter_range(filter_key)
      value = filter_value(filter_key)
      return unless value.respond_to?(:start_date) && value.respond_to?(:end_date)

      value.start_date.beginning_of_day..value.end_date.end_of_day
    end

    def normalize_widget_params(value)
      return {} if value.nil?
      return value.to_h.deep_symbolize_keys if value.respond_to?(:to_h)

      raise ArgumentError, "widget_params must be a Hash"
    end
  end
end
