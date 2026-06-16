# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class SectionResolver
      def self.call(key:, context:)
        new(key, context).call
      end

      def initialize(key, context)
        @key = key.to_s
        @context = context
      end

      def call
        definition = RecordingStudioAdmin.section_for(@key)
        raise DefinitionNotFound, "Section #{@key.inspect} is not registered" unless definition

        RecordingStudioAdmin::Authorization.authorize!(@context)
        raise DefinitionNotFound, "Section #{@key.inspect} is not visible" unless visible?(definition)

        section_recording = if definition.recordable_definition
                              RecordingStudioAdmin::SectionRecordingResolver.call(section: definition,
                                                                                  context: @context)
                            end

        Results::ResolvedSection.new(
          key: definition.key,
          title: definition.evaluate(definition.title, @context),
          subtitle: definition.evaluate(definition.subtitle, @context),
          icon: definition.evaluate(definition.icon, @context),
          links: definition.links.filter_map { |link| link.resolve(@context) },
          widgets: definition.widget_usages.map { |widget_usage| resolve_widget_usage(definition, widget_usage) },
          recordable: section_recording&.recordable,
          recording: section_recording&.recording
        )
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end

      def resolve_widget_usage(definition, widget_usage)
        widget_context = build_widget_context(definition, widget_usage)
        widget = RecordingStudioAdmin.resolve_widget(key: widget_usage.key, context: widget_context)

        overrides = {
          view_variant: widget_usage.view_variant,
          title: resolve_usage_value(definition, widget_usage.title, widget_context),
          chart_type: resolve_usage_value(definition, widget_usage.chart_type, widget_context)
        }.compact

        chart_options = resolve_usage_hash(definition, widget_usage.chart_options, widget_context,
                                           field_name: :chart_options)
        overrides[:chart_options] = (widget.chart_options || {}).deep_merge(chart_options) if chart_options.any?

        overrides.empty? ? widget : widget.with(**overrides)
      end

      def build_widget_context(definition, widget_usage)
        widget_params = resolve_usage_hash(definition, widget_usage.params, @context, field_name: :params)
        return @context if widget_params.empty?

        @context.with_widget_params(widget_params)
      end

      def resolve_usage_value(definition, value, context)
        definition.evaluate(value, context)
      end

      def resolve_usage_hash(definition, value, context, field_name:)
        resolved = resolve_usage_value(definition, value, context)
        return {} if resolved.nil?
        return resolved.to_h.deep_symbolize_keys if resolved.respond_to?(:to_h)

        raise InvalidDefinition, "Section widget #{field_name} must resolve to a Hash"
      end
    end
  end
end
