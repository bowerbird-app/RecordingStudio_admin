# frozen_string_literal: true

module AdminScreens
  UserActivityReviewCompletionWidget = RecordingStudioAdmin::Widget.new("widgets.user_activity.review_completion") do
    type :progress
    title "Review completion"
    subtitle "Resolved review backlog"
    link_label "User reviews"
    metadata do |context|
      range = context.widget_time_range || AdminScreens::Base.widget_preset_range(context, preset_key: :this_week)
      scope = UserActivity.where(created_at: range)
      total = scope.count
      completed = scope.where.not(status: "review").count

      {
        period_label: AdminScreens::Base.widget_preset_label(
          context,
          preset_key: :this_week,
          fallback: "This week"
        ),
        progress_value: completed,
        progress_max: [ total, 1 ].max,
        progress_label: "#{completed} / #{total} reviewed"
      }
    end
    link_to do |context|
      AdminScreens::Base.widget_link_path(context, screen_key: "user_reviews", preset_key: :this_week)
    end
  end
end
