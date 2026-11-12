# frozen_string_literal: true

module AdminScreens
  class Library
    chart do
      title "Added over time"
      type :bar
      series do |context|
        [{
          name: "Items",
          data: AdminScreens::Base.date_series(context.query_result.relation.reorder(nil), bucket: :day)
        }]
      end
    end
  end
end
