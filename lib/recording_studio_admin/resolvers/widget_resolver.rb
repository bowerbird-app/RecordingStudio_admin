# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class WidgetResolver
      def self.call(key:, context:)
        definition = RecordingStudioAdmin.widget_for(key)
        raise DefinitionNotFound, "Widget #{key.inspect} is not registered" unless definition

        definition.resolve(context)
      end
    end
  end
end
