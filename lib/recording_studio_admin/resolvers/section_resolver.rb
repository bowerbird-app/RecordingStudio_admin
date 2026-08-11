# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class SectionResolver
      def self.call(key:, context:, resolve_widgets: true)
        new(key, context, resolve_widgets: resolve_widgets).call
      end

      def self.resolve_widget(key:, widget_key:, context:, view_variant: nil, usage_index: nil)
        new(key, context).resolve_widget(widget_key, view_variant: view_variant, usage_index: usage_index)
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

      def resolve_widget(widget_key, view_variant: nil, usage_index: nil)
        definition = authorized_definition
        widget_usage = resolve_widget_usage_entry(
          definition,
          widget_key: widget_key,
          view_variant: view_variant,
          usage_index: usage_index
        )
        unless widget_usage
          raise DefinitionNotFound,
                "Widget #{widget_key.inspect} is not registered for section #{@key.inspect}"
        end

        resolve_widget_usage(definition, widget_usage, usage_index: usage_index) ||
          raise(DefinitionNotFound, "Widget #{widget_key.inspect} is not available")
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

      def resolve_widget_usage(definition, widget_usage, usage_index: nil)
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
          chart_type: resolve_usage_value(definition, widget_usage.chart_type, widget_context),
          metadata: widget.metadata.merge(usage_metadata(usage_index))
        }.compact

        chart_options = resolve_usage_hash(definition, widget_usage.chart_options, widget_context,
                                           field_name: :chart_options)
        overrides[:chart_options] = (widget.chart_options || {}).deep_merge(chart_options) if chart_options.any?

        if widget_usage.link_to
          overrides[:link_to] = RecordingStudioAdmin::UrlSafety.safe_href(
            resolve_usage_value(definition, widget_usage.link_to, widget_context)
          )
        end

        overrides.empty? ? widget : widget.with(**overrides)
      end

      def resolve_section_widgets(definition)
        definition.widget_usages.each_with_index.filter_map do |widget_usage, index|
          if @resolve_widgets
            resolve_widget_usage(definition, widget_usage, usage_index: index)
          else
            placeholder_widget(definition, widget_usage, usage_index: index)
          end
        end
      end

      def placeholder_widget(definition, widget_usage, usage_index: nil)
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
          title: resolve_usage_value(definition, widget_usage.title,
                                     widget_context) || widget_definition.send(:evaluate, widget_definition.title,
                                                                               widget_context),
          subtitle: widget_definition.send(:evaluate, widget_definition.subtitle, widget_context),
          description: widget_definition.send(:evaluate, widget_definition.description, widget_context),
          info: widget_definition.send(:evaluate, widget_definition.info, widget_context),
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
          metadata: usage_metadata(usage_index),
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

      def resolve_widget_usage_entry(definition, widget_key:, view_variant:, usage_index: nil)
        target_key = widget_key.to_s
        has_variant_selector = view_variant.present?
        normalized_variant = has_variant_selector ? normalize_widget_usage_variant(view_variant) : nil
        indexed_usage = widget_usage_at(definition, usage_index)
        if indexed_usage_matches?(indexed_usage, target_key, has_variant_selector, normalized_variant)
          return indexed_usage
        end
        return if usage_index.present?

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

      def widget_usage_at(definition, usage_index)
        return if usage_index.blank?

        index = Integer(usage_index, exception: false)
        return if index.nil? || index.negative?

        definition.widget_usages[index]
      end

      def indexed_usage_matches?(usage, target_key, has_variant_selector, normalized_variant)
        return false unless usage&.key == target_key
        return true unless has_variant_selector

        usage.view_variant == normalized_variant
      end

      def usage_metadata(usage_index)
        index = Integer(usage_index, exception: false)
        return {} if index.nil?

        { recording_studio_admin_widget_usage_index: index }
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
