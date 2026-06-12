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
        relation.respond_to?(:count) ? relation.count : Array(relation).size
      end

      def percent_change(current, previous)
        return if previous.nil?
        return 0 if previous.zero? && current.zero?
        return if previous.zero?

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
