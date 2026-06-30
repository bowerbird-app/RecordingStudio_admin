# frozen_string_literal: true

module AdminScreens
  class UserSignIns
    widget :sign_in_activity do
      type :chart
      title "Sign-in activity"
      description "Seven-day sign-in volume with the current period total and percentage change."
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
        UserActivity.where(action: "signed_in", created_at: range).count
      end
      change { |_context| AdminScreens::Base.period_change_label(UserActivity.where(action: "signed_in")) }
      chart_type :area
      series do
        range = _1.widget_time_range || AdminScreens::Base.widget_preset_range(_1, preset_key: :this_week)
        [ {
          name: "Sign-in activity",
          data: AdminScreens::Base.date_series(
            UserActivity.where(action: "signed_in", created_at: range),
            bucket: _1.widget_group_by(default: :day)
          )
        } ]
      end
      chart_options { { height: 220 } }
      link_to do |context|
        AdminScreens::Base.widget_link_path(context, screen_key: "user_sign_ins", preset_key: :this_week)
      end
    end
  end
end