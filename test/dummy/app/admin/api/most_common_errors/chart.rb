# frozen_string_literal: true

module AdminScreens
  class MostCommonErrors
    chart do
      title "Top error classes"
      subtitle "By total occurrences in the selected date range"
      type :pie
      series do |context|
        AdminScreens::MostCommonErrors.grouped_error_counts(context.query_result.relation.order(Arel.sql("error_count DESC")),
                                                            limit: 5).map do |entry|
          entry[:value]
        end
      end
      options do |context|
        breakdown = AdminScreens::MostCommonErrors.grouped_error_counts(
          context.query_result.relation.order(Arel.sql("error_count DESC")),
          limit: 5
        )
        {
          labels: breakdown.map { |entry| entry[:label] },
          legend: { position: "bottom" }
        }
      end
    end
  end
end