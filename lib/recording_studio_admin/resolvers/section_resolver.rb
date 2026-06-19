# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class SectionResolver
      def self.call(key:, context:, resolve_widgets: true)
        new(key, context, resolve_widgets: resolve_widgets).call
      end

      def self.resolve_widget(key:, widget_key:, view_variant: nil, context:)
        new(key, context).resolve_widget(widget_key, view_variant: view_variant)
      end

      def initialize(key, context, resolve_widgets: true)
        @key = key.to_s
        @context = context
        @resolve_widgets = resolve_widgets
      end

      def call
        definition = authorized_definition

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
          widgets: resolve_section_widgets(definition),
          recordable: section_recording&.recordable,
          recording: section_recording&.recording
        )
      end

      def resolve_widget(widget_key, view_variant: nil)
        definition = authorized_definition
        widget_usage = resolve_widget_usage_entry(definition, widget_key: widget_key, view_variant: view_variant)
        raise DefinitionNotFound, "Widget #{widget_key.inspect} is not registered for section #{@key.inspect}" unless widget_usage

        resolve_widget_usage(definition, widget_usage) || raise(DefinitionNotFound,
                                                                "Widget #{widget_key.inspect} is not available")
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end

      def enabled?(definition)
        RecordingStudioAdmin.section_enabled?(
          key: definition.key,
          recording: @context.access_recording,
          context: @context
        )
      end

      def resolve_widget_usage(definition, widget_usage)
        widget_definition = RecordingStudioAdmin.widget_for(widget_usage.key)
        return unless widget_definition

        widget_radius = widget_usage.effective_blast_radius(widget_definition)
        return unless RecordingStudioAdmin::BlastRadius.allowed?(widget_radius, context: @context,
                                                                                container: definition)

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

      def resolve_section_widgets(definition)
        definition.widget_usages.filter_map do |widget_usage|
          if @resolve_widgets
            resolve_widget_usage(definition, widget_usage)
          else
            placeholder_widget(definition, widget_usage)
          end
        end
      end

      def placeholder_widget(definition, widget_usage)
        widget_definition = RecordingStudioAdmin.widget_for(widget_usage.key)
        return unless widget_definition

        widget_radius = widget_usage.effective_blast_radius(widget_definition)
        return unless RecordingStudioAdmin::BlastRadius.allowed?(widget_radius, context: @context,
                                                                                container: definition)

        widget_context = build_widget_context(definition, widget_usage)
        widget_type = widget_definition.send(:evaluate, widget_definition.type, widget_context)
        chart_type = resolve_usage_value(definition, widget_usage.chart_type, widget_context) ||
                     widget_definition.send(:evaluate, widget_definition.chart_type, widget_context)
        Results::ResolvedWidget.new(
          key: widget_definition.key,
          type: widget_type.to_s.downcase.to_sym,
          title: resolve_usage_value(definition, widget_usage.title, widget_context) || widget_definition.send(:evaluate, widget_definition.title, widget_context),
          subtitle: widget_definition.send(:evaluate, widget_definition.subtitle, widget_context),
          description: widget_definition.send(:evaluate, widget_definition.description, widget_context),
          value: nil,
          change: nil,
          change_good_when: :neutral,
          link_to: nil,
          link_label: widget_definition.send(:evaluate, widget_definition.link_label, widget_context),
          series: nil,
          chart_type: chart_type,
          chart_options: {},
          list_options: {},
          items: nil,
          rows: nil,
          metadata: {},
          view_variant: widget_usage.view_variant,
          show_metric: false,
          show_change: false,
          show_period: false
        )
      end

      def authorized_definition
        definition = RecordingStudioAdmin.section_for(@key)
        raise DefinitionNotFound, "Section #{@key.inspect} is not registered" unless definition

        RecordingStudioAdmin::Authorization.authorize!(@context)
        RecordingStudioAdmin::BlastRadius.authorize!(definition, context: @context,
                                                                 label: "Section #{definition.key.inspect}")
        raise DefinitionNotFound, "Section #{@key.inspect} is not enabled for this root" unless enabled?(definition)
        raise DefinitionNotFound, "Section #{@key.inspect} is not visible" unless visible?(definition)

        definition
      end

      def build_widget_context(definition, widget_usage)
        widget_params = resolve_usage_hash(definition, widget_usage.params, @context, field_name: :params)
        return @context if widget_params.empty?

        @context.with_widget_params(widget_params)
      end

      def resolve_widget_usage_entry(definition, widget_key:, view_variant:)
        target_key = widget_key.to_s
        has_variant_selector = view_variant.present?
        normalized_variant = has_variant_selector ? normalize_widget_usage_variant(view_variant) : nil

        definition.widget_usages.find do |usage|
          next false unless usage.key == target_key
          next true unless has_variant_selector

          usage.view_variant == normalized_variant
        end
      end

      def normalize_widget_usage_variant(value)
        return nil if value.to_s == "__default__"

        RecordingStudioAdmin::Section.normalize_view_variant(value)
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
