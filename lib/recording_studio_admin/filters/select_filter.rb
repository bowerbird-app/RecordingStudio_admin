# frozen_string_literal: true

module RecordingStudioAdmin
  module Filters
    class SelectFilter
      def initialize(definition)
        @definition = definition
      end

      def normalize(params)
        value = params[@definition.param_key] || params[@definition.param_key.to_s]
        return normalize_many(value) if value.is_a?(Array)
        return if value.nil? || value.to_s.empty?

        allowed = @definition.allowed_values
        return value if allowed.empty?

        value if allowed.include?(value.to_s)
      end

      # Repeated params (status[]=a&status[]=b) keep each allowed, non-blank value.
      # The default apply becomes WHERE field IN (...). One kept value is returned as a scalar.
      def normalize_many(values)
        allowed = @definition.allowed_values
        kept = values.map(&:to_s).reject(&:empty?).uniq
        kept &= allowed unless allowed.empty?
        return if kept.empty?

        kept.one? ? kept.first : kept
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
