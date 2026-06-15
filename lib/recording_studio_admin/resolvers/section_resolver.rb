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
        raise DefinitionNotFound, "Section #{@key.inspect} is not visible" unless visible?(definition)

        section_recording = RecordingStudioAdmin::SectionRecordingResolver.call(section: definition, context: @context)

        Results::ResolvedSection.new(
          key: definition.key,
          title: definition.evaluate(definition.title, @context),
          subtitle: definition.evaluate(definition.subtitle, @context),
          links: definition.links.filter_map { |link| link.resolve(@context) },
          widgets: definition.widget_usages.map do |widget_usage|
            widget = RecordingStudioAdmin.resolve_widget(key: widget_usage.key, context: @context)
            widget_usage.view_variant.nil? ? widget : widget.with(view_variant: widget_usage.view_variant)
          end,
          recordable: section_recording&.recordable,
          recording: section_recording&.recording
        )
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end
    end
  end
end
