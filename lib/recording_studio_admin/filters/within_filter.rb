# frozen_string_literal: true

module RecordingStudioAdmin
  module Filters
    class WithinFilter
      def initialize(definition)
        @definition = definition
      end

      def normalize(params, context = nil)
        return if context.nil?

        raw = RecordingScope.read_param(params, @definition.param_key)
        context.within_catalog_for(@definition).allowed_id(raw)
      end

      def apply(relation, value, context)
        return relation if value.nil?
        return relation unless relation.respond_to?(:where)

        relation.where(id: context.within_catalog_for(@definition).subtree_ids(value))
      end
    end
  end
end
