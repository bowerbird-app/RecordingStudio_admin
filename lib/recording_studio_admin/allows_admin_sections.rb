# frozen_string_literal: true

module RecordingStudioAdmin
  module AllowsAdminSections
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def recording_studio_admin_sections(&block)
        @recording_studio_admin_sections_definition = if block
                                                        build_recording_studio_admin_sections_definition(block)
                                                      else
                                                        AdminSectionsDefinition.new
                                                      end
      end

      def recording_studio_admin_section_keys_for(recordable, recording, context)
        definition = @recording_studio_admin_sections_definition
        return unless definition

        keys = if definition.respond_to?(:call)
                 call_recording_studio_admin_sections_definition(definition, recordable, recording, context)
               else
                 definition.keys
               end

        RecordingStudioAdmin.normalize_admin_section_keys(keys)
      end

      private

      def build_recording_studio_admin_sections_definition(block)
        return block unless block.arity.zero?

        AdminSectionsDefinition.new.tap { |definition| definition.instance_eval(&block) }
      end

      def call_recording_studio_admin_sections_definition(definition, recordable, recording, context)
        case definition.arity
        when 0 then definition.call
        when 1, -1 then definition.call(recordable)
        when 2 then definition.call(recordable, recording)
        else definition.call(recordable, recording, context)
        end
      end
    end

    class AdminSectionsDefinition
      attr_reader :keys

      def initialize
        @keys = []
      end

      def section(key)
        @keys << key
      end
    end
  end
end
