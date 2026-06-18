# frozen_string_literal: true

module RecordingStudioAdmin
  module Resolvers
    class ResourceResolver
      def self.call(key:, context:, action:, record: nil)
        new(key, context, action, record).call
      end

      def initialize(key, context, action, record)
        @key = key.to_s
        @context = context
        @action = action.to_s.downcase.to_sym
        @record = record
      end

      def call
        definition = RecordingStudioAdmin.resource_for(@key)
        raise DefinitionNotFound, "Resource #{@key.inspect} is not registered" unless definition
        action_definition = definition.action_for(@action)
        raise AuthorizationFailed, "Resource #{@key.inspect} does not define action #{@action}" unless action_definition

        section = RecordingStudioAdmin.section_for(definition.section_key!)
        raise DefinitionNotFound, "Resource #{@key.inspect} references unknown section #{definition.section_key.inspect}" unless section

        authorize_section!(section, role: action_definition.required_access_role)
  RecordingStudioAdmin::BlastRadius.authorize!(section, context: @context, label: "Section #{section.key.inspect}")
  RecordingStudioAdmin::BlastRadius.authorize!(definition, context: @context, container: section,
                 label: "Resource #{definition.key.inspect}")
  RecordingStudioAdmin::BlastRadius.authorize!(action_definition, context: @context, container: definition,
                       label: "Resource #{definition.key}.#{@action}")
        raise DefinitionNotFound, "Resource #{@key.inspect} is not enabled for this root" unless enabled?(section)
        raise DefinitionNotFound, "Resource #{@key.inspect} is not visible" unless visible?(definition) && visible?(section)
        raise AuthorizationFailed, "Resource #{@key.inspect} action #{@action} is not visible" unless action_definition.visible?(@record, @context)

        action_definition
      end

      private

      def authorize_section!(section, role:)
        unless section.recordable_definition
          RecordingStudioAdmin::Authorization.authorize!(@context, role: role)
          return
        end

        RecordingStudioAdmin::Authorization.authorize!(@context, role: role)
        section_recording = RecordingStudioAdmin::SectionRecordingResolver.call(section: section, context: @context)
        RecordingStudioAdmin::Authorization.authorize!(
          @context,
          recording: section_recording&.recording || @context.access_recording,
          role: role
        )
      end

      def visible?(definition)
        return true unless definition.visible_if

        definition.visible_if.call(@context)
      end

      def enabled?(section)
        RecordingStudioAdmin.section_enabled?(
          key: section.key,
          recording: @context.access_recording,
          context: @context
        )
      end
    end
  end
end