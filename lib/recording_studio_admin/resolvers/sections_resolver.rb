# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class SectionsResolver
      def self.call(context:)
        new(context).call
      end

      def initialize(context)
        @context = context
      end

      def call
        RecordingStudioAdmin::Authorization.authorize!(@context)

        RecordingStudioAdmin.sections.values.filter_map do |definition|
          next unless visible?(definition)

          Results::ResolvedSectionListItem.new(
            key: definition.key,
            title: definition.evaluate(definition.title, @context),
            subtitle: definition.evaluate(definition.subtitle, @context),
            icon: definition.evaluate(definition.icon, @context),
            url: @context.admin_section_path(definition.key)
          )
        end.sort_by { |section| [section.title.to_s, section.key.to_s] }
      end

      private

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end
    end
  end
end
