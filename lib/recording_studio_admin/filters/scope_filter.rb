# frozen_string_literal: true

module RecordingStudioAdmin
  module Filters
    class ScopeFilter
      def initialize(definition)
        @definition = definition
      end

      def normalize(params)
        RecordingScope.mode_from(params[@definition.param_key] || params[@definition.param_key.to_s])
      end

      def apply(relation, value, context)
        return @definition.options[:apply].call(relation, value, context) if @definition.options[:apply]

        relation
      end
    end

    class RecordableTypeFilter
      def initialize(definition)
        @definition = definition
      end

      def normalize(params)
        RecordingScope.type_from(
          params[@definition.param_key] || params[@definition.param_key.to_s],
          @definition.allowed_values
        )
      end

      def apply(relation, value, context)
        return relation if value.nil?
        return @definition.options[:apply].call(relation, value, context) if @definition.options[:apply]

        relation
      end
    end
  end
end
