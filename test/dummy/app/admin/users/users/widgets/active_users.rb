# frozen_string_literal: true

module AdminScreens
  class Users
    widget :active_users do
      type :chart
      title "Active users"
      description "Daily unique users across the last seven days, plus the current period delta."
      subtitle "Daily unique users"
      metadata do |context|
        {
          period_label: AdminScreens::Base.widget_preset_label(
            context,
            preset_key: :this_week,
            fallback: "This week"
          )
        }
      end
      value do |context|
        range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
        UserActivity.where(created_at: range).distinct.count(:email)
      end
      change { |_context| AdminScreens::Base.period_change_label(UserActivity.all, distinct_field: :email) }
      chart_type :line
      series do
        range = _1.widget_time_range || AdminScreens::Base.widget_preset_range(_1, preset_key: :this_week)
        [ {
          name: "Active users",
          data: AdminScreens::Base.distinct_date_series(
            UserActivity.where(created_at: range),
            distinct_field: :email,
            bucket: _1.widget_group_by(default: :day)
          )
        } ]
      end
      chart_options { { height: 220 } }
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "users", preset_key: :this_week)
      end
    end
  end
end