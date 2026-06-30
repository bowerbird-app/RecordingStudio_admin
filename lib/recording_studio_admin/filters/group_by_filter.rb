# frozen_string_literal: true

module RecordingStudioAdmin
  module Filters
    class GroupByFilter
      DEFAULT_VALUES = %w[hour day week month year].freeze

      def initialize(definition)
        @definition = definition
      end

      def normalize(params)
        raw = params[@definition.param_key] || params[@definition.param_key.to_s]
        value = raw.to_s
        allowed.include?(value) ? value.to_sym : default_value
      end

      def apply(relation, _value, _context)
        relation
      end

      private

      def allowed
        values = @definition.options[:values] || DEFAULT_VALUES
        Array(values).map(&:to_s) & DEFAULT_VALUES
      end

      def default_value
        default = (@definition.options[:default] || :day).to_s
        (allowed.include?(default) ? default : allowed.first).to_sym
      end
    end
  end
end
