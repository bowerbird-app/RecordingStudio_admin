# frozen_string_literal: true

module AdminScreens
  class UserActivityScreen
    chart do
      title "Activity over time"
      type :line
      series do |context|
        [ {
          name: "Activities",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end