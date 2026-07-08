# frozen_string_literal: true

module AdminScreens
  class ApiRequests
    chart do
      title "Requests over time"
      type :line
      series do |context|
        [ {
          name: "Requests",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end
