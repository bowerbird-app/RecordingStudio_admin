# frozen_string_literal: true

module RecordingStudioAdmin
  module Filters
    class SelectFilter
      def initialize(definition)
        @definition = definition
      end

      def normalize(params)
        value = params[@definition.param_key] || params[@definition.param_key.to_s]
        return if value.nil? || value.to_s.empty?

        allowed = @definition.allowed_values
        return value if allowed.empty?

        value if allowed.include?(value.to_s)
      end

      def apply(relation, value, context)
        return relation if value.nil?
        return @definition.options[:apply].call(relation, value, context) if @definition.options[:apply]

        field = @definition.options[:field] || @definition.key
        relation.respond_to?(:where) ? relation.where(field => value) : relation
      end
    end
  end
end
