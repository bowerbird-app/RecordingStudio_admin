# frozen_string_literal: true

module AdminScreens
  class BackgroundJobs
    chart do
      title "Jobs over time"
      type :bar
      series do |context|
        [ {
          name: "Jobs",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end
