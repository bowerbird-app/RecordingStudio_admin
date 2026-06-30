# frozen_string_literal: true

module AdminScreens
  class UserSignIns
    chart do
      title "Sign-ins over time"
      type :area
      series do |context|
        [ {
          name: "Sign-ins",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end