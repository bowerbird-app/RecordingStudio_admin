# frozen_string_literal: true

module RecordingStudioAdmin
  class Section < Definitions::Base
    class << self
      attr_reader :links_value, :widget_keys_value

      def inherited(subclass)
        super
        subclass.instance_variable_set(:@links_value, [])
        subclass.instance_variable_set(:@widget_keys_value, [])
      end

      def link(name, text:, url:, style: :secondary, visible_if: nil)
        @links_value << Definitions::ButtonDefinition.new(name.to_sym, text, url, style, visible_if)
      end

      def widget(key)
        @widget_keys_value << key.to_s
      end

      def links
        @links_value || []
      end

      def widget_keys
        @widget_keys_value || []
      end
    end
  end
end
