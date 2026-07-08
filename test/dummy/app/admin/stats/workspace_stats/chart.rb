# frozen_string_literal: true

module AdminScreens
  class WorkspaceStats
    chart do
      title "Content created over time"
      type :bar
      series do |context|
        [ {
          name: "Items",
          data: AdminScreens::Base.date_series(
            context.query_result.relation.reorder(nil),
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end
