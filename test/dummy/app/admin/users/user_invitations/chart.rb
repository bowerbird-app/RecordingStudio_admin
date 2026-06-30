# frozen_string_literal: true

module AdminScreens
  class UserInvitations
    chart do
      title "Invitations over time"
      type :line
      series do |context|
        [ {
          name: "Invitations",
          data: AdminScreens::Base.date_series(
            context.query_result.relation,
            bucket: context.filter_value(:group_by) || :day
          )
        } ]
      end
    end
  end
end