# frozen_string_literal: true

module RecordingStudioAdmin
  SectionRecordableDefinition = Data.define(:class_name, :find_or_create_by, :parent, :parent_recording, :action)

  class Section < Definitions::Base
    class << self
      attr_reader :links_value, :widget_keys_value, :recordable_definition_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@links_value, [])
        subclass.instance_variable_set(:@widget_keys_value, [])
        subclass.instance_variable_set(:@recordable_definition_value, nil)
      end

      def link(name, text:, url:, style: :secondary, visible_if: nil)
        @links_value << Definitions::ButtonDefinition.new(name.to_sym, text, url, style, visible_if)
      end

      def widget(key)
        @widget_keys_value << key.to_s
      end

      def recordable(class_name, find_or_create_by:, parent: nil, parent_recording: nil, action: "created")
        raise ArgumentError, "parent or parent_recording is required" unless parent || parent_recording

        @recordable_definition_value = SectionRecordableDefinition.new(
          class_name: class_name,
          find_or_create_by: find_or_create_by,
          parent: parent,
          parent_recording: parent_recording,
          action: action
        )
      end

      def links
        @links_value || []
      end

      def widget_keys
        @widget_keys_value || []
      end

      def recordable_definition
        @recordable_definition_value
      end
    end
  end
end
