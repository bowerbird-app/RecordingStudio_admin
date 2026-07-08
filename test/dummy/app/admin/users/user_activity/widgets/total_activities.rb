# frozen_string_literal: true

module AdminScreens
  UserActivityTotalActivitiesWidget = RecordingStudioAdmin::Widget.new("widgets.user_activity.total_activities") do
    title "Total activities"
    description "Total user activity records for the selected period."
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
      UserActivity.where(created_at: range).count
    end
    change do |_context|
      AdminScreens::Base.period_change_label(UserActivity.all)
    end
    link_to do |context|
      AdminScreens::Base.widget_link_path(context, screen_key: "user_activity", preset_key: :this_week)
    end
  end
end
