# frozen_string_literal: true

module RecordingStudioAdmin
  module Results
    class QueryResult
      attr_reader :relation, :count, :previous_count, :change_percent, :change_direction

      def initialize(relation:, previous_count: nil)
        @relation = relation
        @count = relation_count(relation)
        @previous_count = previous_count
        @change_percent = percent_change(@count, previous_count)
        @change_direction = direction(@count, previous_count)
      end

      private

      def relation_count(relation)
        return Array(relation).size unless relation.respond_to?(:count)

        return grouped_relation_count(relation) if grouped_select_relation?(relation)

        normalized_count(relation.count)
      rescue StandardError => e
        raise unless active_record_statement_invalid?(e) && relation.respond_to?(:except)

        grouped_relation_count(relation)
      end

      def active_record_statement_invalid?(error)
        defined?(ActiveRecord::StatementInvalid) && error.is_a?(ActiveRecord::StatementInvalid)
      end

      def grouped_select_relation?(relation)
        relation.respond_to?(:group_values) && relation.respond_to?(:select_values) &&
          relation.group_values.any? && relation.select_values.any?
      end

      def grouped_relation_count(relation)
        normalized_count(relation.except(:select, :order).count)
      end

      def normalized_count(value)
        return value.size if value.is_a?(Hash)

        value
      end

      def percent_change(current, previous)
        return if previous.nil?
        return 0 if previous.zero? && current.zero?
        return 100 if previous.zero? && current.positive?

        ((current - previous) / previous.to_f) * 100
      end

      def direction(current, previous)
        return if previous.nil?
        return :up if current > previous
        return :down if current < previous

        :flat
      end
    end
  end
end
