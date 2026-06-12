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

        Results::ResolvedSection.new(
          key: definition.key,
          title: definition.evaluate(definition.title, @context),
          subtitle: definition.evaluate(definition.subtitle, @context),
          links: definition.links.filter_map { |link| link.resolve(@context) },
          widgets: definition.widget_keys.map { |key| RecordingStudioAdmin.resolve_widget(key: key, context: @context) }
        )
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end
    end
  end
end
