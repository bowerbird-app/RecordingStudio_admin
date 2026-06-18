# frozen_string_literal: true

module AdminScreens
  class MostCommonErrors < Base
    class << self
      def top_error_breakdown(relation, limit: 5)
        relation
          .group(:error_class)
          .order(Arel.sql("COUNT(*) DESC"))
          .limit(limit)
          .count
          .map { |error_class, count| { label: error_class, value: count } }
      end

      def grouped_error_counts(relation, limit: nil)
        scoped = relation
        scoped = scoped.limit(limit) if limit

        scoped.map do |row|
          {
            label: row.error_class,
            value: row.error_count.to_i
          }
        end
      end
    end

    key "most_common_errors"
    icon :chart_pie
    title "Most common errors"
    subtitle "Track the highest-volume API error classes"
    query do |_context|
      ApiError
        .where.not(error_class: [ nil, "" ])
        .select("error_class, COUNT(*) AS error_count")
        .group(:error_class)
    end
    filter :date_range, field: :created_at, default: :last_30_days
  end
end