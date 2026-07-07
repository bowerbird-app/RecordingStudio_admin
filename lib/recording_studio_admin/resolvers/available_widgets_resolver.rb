# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class AvailableWidgetsResolver
      VALID_PLACEMENTS = %i[all root descendant].freeze
      VALID_INCLUDES = %i[section_widgets linked_screen_widgets].freeze
      DEFAULT_RECORDING = :__recording_studio_admin_default__

      def self.call(context:, recording: DEFAULT_RECORDING, placement: :all,
                    include: %i[section_widgets linked_screen_widgets])
        new(context: context, recording: recording, placement: placement, include: include).call
      end

      def initialize(context:, recording:, placement:, include:)
        @context = context
        @recording = recording == DEFAULT_RECORDING ? context.access_recording : recording
        @placement = normalize_placement(placement)
        @include = normalize_include(include)
      end

      def call
        RecordingStudioAdmin::Authorization.authorize!(@context, recording: @recording)

        widgets = available_section_definitions.flat_map do |section_definition|
          widgets = []
          widgets.concat(section_widgets_for(section_definition)) if @include.include?(:section_widgets)
          widgets.concat(linked_screen_widgets_for(section_definition)) if @include.include?(:linked_screen_widgets)
          widgets
        end

        widgets.compact.uniq do |widget|
          [widget.key, widget.section_key, widget.screen_key, widget.source, widget.params]
        end.sort_by do |widget|
          [widget.section_key.to_s, widget.screen_key.to_s, widget.key.to_s, widget.source.to_s]
        end
      end

      private

      def available_section_definitions
        enabled_keys = RecordingStudioAdmin.enabled_admin_section_keys(recording: @recording, context: @context)
        return enabled_section_definitions(enabled_keys) if enabled_keys

        legacy_section_definitions
      end

      def enabled_section_definitions(enabled_keys)
        enabled_keys.filter_map do |key|
          definition = RecordingStudioAdmin.sections[key.to_s]
          definition if definition && visible?(definition) && blast_radius_allowed?(definition)
        end
      end

      def legacy_section_definitions
        RecordingStudioAdmin.sections.values.filter_map do |definition|
          next unless visible?(definition)
          next unless available_for_placement?(definition)
          next unless blast_radius_allowed?(definition)

          definition
        end
      end

      def section_widgets_for(section_definition)
        section_definition.widget_usages.filter_map do |widget_usage|
          widget_definition = RecordingStudioAdmin.widget_for(widget_usage.key)
          next unless widget_definition

          widget_radius = widget_usage.effective_blast_radius(widget_definition)
          next unless blast_radius_allowed?(widget_radius, container: section_definition)

          build_widget(
            widget_definition,
            section_key: section_definition.key,
            source: :section_widget,
            view_variant: widget_usage.view_variant,
            params: resolve_section_usage_hash(section_definition, widget_usage.params, field_name: :params),
            title_override: resolve_section_usage_value(section_definition, widget_usage.title),
            chart_type_override: resolve_section_usage_value(section_definition, widget_usage.chart_type)
          )
        end
      end

      def linked_screen_widgets_for(section_definition)
        linked_screen_definitions(section_definition).flat_map do |screen_definition|
          next [] unless blast_radius_allowed?(screen_definition, container: section_definition)

          screen_definition.widget_usages.map do |widget_usage|
            widget_definition = RecordingStudioAdmin.widget_for(widget_usage.key)
            next unless widget_definition

            widget_radius = widget_usage.effective_blast_radius(widget_definition)
            next unless blast_radius_allowed?(widget_radius, container: screen_definition)

            build_widget(
              widget_definition,
              section_key: section_definition.key,
              screen_key: screen_definition.key,
              source: :linked_screen_widget,
              view_variant: widget_usage.view_variant,
              params: resolve_screen_usage_hash(screen_definition, widget_usage.params, field_name: :params),
              title_override: resolve_screen_usage_value(screen_definition, widget_usage.title),
              chart_type_override: resolve_screen_usage_value(screen_definition, widget_usage.chart_type)
            )
          end.compact
        end
      end

      def linked_screen_definitions(section_definition)
        section_definition.links.filter_map do |link|
          resolved_link = link.resolve(@context)
          screen_definition_for_link(resolved_link) if resolved_link
        end.uniq(&:key)
      end

      def screen_definition_for_link(resolved_link)
        link_path = resolved_link.url.to_s.split("?").first
        RecordingStudioAdmin.screens.values.find do |definition|
          @context.admin_screen_path(definition.key).to_s.split("?").first == link_path
        end
      end

      def build_widget(widget_definition, section_key:, source:, view_variant:, params:, screen_key: nil,
                       title_override: nil, chart_type_override: nil)
        title = title_override || resolve_widget_value(widget_definition.title)
        description = resolve_widget_value(widget_definition.description)
        type = normalize_widget_type(resolve_widget_value(widget_definition.type))
        chart_type = chart_type_override || resolve_widget_value(widget_definition.chart_type)

        Results::ResolvedAvailableWidget.new(
          key: widget_definition.key,
          title: title,
          description: description,
          type: type,
          chart_type: normalize_chart_type(chart_type),
          screen_key: screen_key,
          section_key: section_key,
          source: source,
          recording: @recording,
          recordable: recordable,
          view_variant: view_variant,
          params: normalize_hash(params),
          surface_key: @context.surface&.key
        )
      end

      def recordable
        @recording.recordable if @recording.respond_to?(:recordable)
      end

      def resolve_section_usage_value(section_definition, value)
        return if value.nil?

        section_definition.evaluate(value, @context)
      end

      def resolve_section_usage_hash(section_definition, value, field_name:)
        resolved = resolve_section_usage_value(section_definition, value)
        return {} if resolved.nil?
        return resolved.to_h.deep_symbolize_keys if resolved.respond_to?(:to_h)

        raise InvalidDefinition, "Section widget #{field_name} must resolve to a Hash"
      end

      def resolve_screen_usage_value(screen_definition, value)
        return if value.nil?

        screen_definition.evaluate(value, @context)
      end

      def resolve_screen_usage_hash(screen_definition, value, field_name:)
        resolved = resolve_screen_usage_value(screen_definition, value)
        return {} if resolved.nil?
        return resolved.to_h.deep_symbolize_keys if resolved.respond_to?(:to_h)

        raise InvalidDefinition, "Screen widget #{field_name} must resolve to a Hash"
      end

      def resolve_widget_value(value)
        return value.call(@context) if value.respond_to?(:call)

        value
      end

      def normalize_widget_type(value)
        normalized = (value || :number).to_s.downcase.to_sym
        normalized == :stat ? :number : normalized
      end

      def normalize_chart_type(value)
        return unless value

        RecordingStudioAdmin::Widgets::Presenter.renderable_chart_type(value, default: :line)
      end

      def normalize_hash(value)
        return {} if value.nil?
        return value.to_h.deep_symbolize_keys if value.respond_to?(:to_h)

        value
      end

      def normalize_placement(value)
        normalized = value.to_s.downcase.to_sym
        return normalized if VALID_PLACEMENTS.include?(normalized)

        raise ArgumentError, "placement must be one of #{VALID_PLACEMENTS.join(', ')}"
      end

      def normalize_include(value)
        normalized = Array(value).map { |entry| entry.to_s.downcase.to_sym }.uniq
        unknown = normalized - VALID_INCLUDES
        raise ArgumentError, "include must be drawn from #{VALID_INCLUDES.join(', ')}" if unknown.any?

        normalized
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end

      def blast_radius_allowed?(definition, container: nil)
        RecordingStudioAdmin::BlastRadius.allowed?(definition, context: @context, recording: @recording,
                                                               container: container)
      end

      def available_for_placement?(definition)
        scope = definition.availability_scope
        return custom_scope_matches?(scope) if scope.respond_to?(:call)
        return true if @placement == :all

        case scope
        when :all
          true
        when :root
          @placement == :root && root_recording?(@recording)
        when :descendant
          @placement == :descendant && descendant_recording?(@recording)
        else
          false
        end
      end

      def custom_scope_matches?(callable)
        case callable.arity
        when 0 then callable.call
        when 1, -1 then callable.call(@recording)
        when 2 then callable.call(@recording, @context)
        else callable.call(@recording, @context, @placement)
        end
      end

      def root_recording?(recording)
        return false unless recording
        return recording.parent_recording.nil? if recording.respond_to?(:parent_recording)
        if recording.respond_to?(:root_recording) && recording.root_recording
          return recording.root_recording.equal?(recording)
        end

        RecordingStudio.root_recording_or_self(recording).equal?(recording)
      end

      def descendant_recording?(recording)
        return false unless recording
        return recording.parent_recording.present? if recording.respond_to?(:parent_recording)
        if recording.respond_to?(:root_recording) && recording.root_recording
          return !recording.root_recording.equal?(recording)
        end

        !root_recording?(recording)
      end
    end
  end
end
