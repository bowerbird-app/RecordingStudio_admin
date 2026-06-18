# frozen_string_literal: true

module AdminScreens
  class UserGeography
    chart do
      title "Activity by country"
      subtitle "Mapped from demo user activity actions"
      type :geo
      series do |context|
        [ {
          name: "User activities",
          data: AdminScreens::UserGeography.geo_series(context.query_result.relation)
        } ]
      end
      options do
        {
          chart: { height: 360 },
          geo: { map: "world", key_field: "iso2" }
        }
      end
    end
  end
end