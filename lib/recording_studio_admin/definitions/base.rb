# frozen_string_literal: true

module RecordingStudioAdmin
  module Definitions
    class Base
      class << self
        attr_reader :key_value, :title_value, :subtitle_value, :buttons_value, :visible_if_value

        def inherited(subclass)
          super
          subclass.instance_variable_set(:@buttons_value, [])
        end

        def key(value = nil)
          @key_value = value.to_s if value
          @key_value
        end

        def title(value = nil, &block)
          @title_value = block || value if value || block
          @title_value
        end

        def subtitle(value = nil, &block)
          @subtitle_value = block || value if value || block
          @subtitle_value
        end

        def button(name, text:, url:, style: :secondary, visible_if: nil)
          @buttons_value << ButtonDefinition.new(name.to_sym, text, url, style, visible_if)
        end

        def visible_if(callable = nil, &block)
          @visible_if_value = callable || block if callable || block
          @visible_if_value
        end

        def evaluate(value, context, *args)
          value.respond_to?(:call) ? value.call(*args, context) : value
        rescue ArgumentError
          value.call(context)
        end
      end
    end

    ButtonDefinition = Data.define(:name, :text, :url, :style, :visible_if) do
      def visible?(context)
        return true unless visible_if

        visible_if.call(context)
      end

      def resolve(context)
        return unless visible?(context)

        Results::ResolvedButton.new(name: name, text: resolve_value(text, context), url: resolve_value(url, context), style: style)
      end

      private

      def resolve_value(value, context)
        value.respond_to?(:call) ? value.call(context) : value
      end
    end
  end
end
