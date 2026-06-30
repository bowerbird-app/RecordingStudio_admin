# frozen_string_literal: true

module AdminScreens
  class UserReviews
    chart do
      title "Review activity"
      type :bar
      series do |context|
        [ {
          name: "Review queue",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end