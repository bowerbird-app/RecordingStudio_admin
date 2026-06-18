# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class WidgetResolver
      def self.call(key:, context:)
        definition = RecordingStudioAdmin.widget_for(key)
        raise DefinitionNotFound, "Widget #{key.inspect} is not registered" unless definition
        return resolve_screen_widget(definition, context) if definition.screen_key

        RecordingStudioAdmin::Authorization.authorize!(context)
        RecordingStudioAdmin::BlastRadius.authorize!(definition, context: context, label: "Widget #{definition.key.inspect}")
        definition.resolve(context)
      end

      def self.resolve_screen_widget(definition, context)
        screen = RecordingStudioAdmin.resolve_screen(key: definition.screen_key, context: context)
        screen.widgets.find { |widget| widget.key == definition.key } || definition.resolve(context)
      end
    end
  end
end
