# frozen_string_literal: true

module RecordingStudioAdmin
  module Definitions
    FilterDefinition = Struct.new(:key, :type, :options) do
      def param_key
        (options[:param] || key).to_sym
      end

      def normalize(params, context = nil)
        filter.normalize(params, context)
      end

      def apply(relation, value, context)
        return relation unless applies_to_relation?(relation)

        filter.apply(relation, value, context)
      end

      def allowed_values(context = nil)
        raw = options[:values] || options[:options]
        raw = Callable.resolve(raw, context) if raw.respond_to?(:call)
        Array(raw).map(&:to_s)
      end

      private

      def filter
        case type.to_sym
        when :date_range then Filters::DateRangeFilter.new(self)
        when :group_by then Filters::GroupByFilter.new(self)
        else Filters::SelectFilter.new(self)
        end
      end

      def applies_to_relation?(relation)
        relation.respond_to?(:where) || options[:apply].respond_to?(:call)
      end
    end
  end
end
