# frozen_string_literal: true

module AdminScreens
  class ApiErrors
    chart do
      title "Errors over time"
      type :bar
      series do |context|
        [ {
          name: "Errors",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end
