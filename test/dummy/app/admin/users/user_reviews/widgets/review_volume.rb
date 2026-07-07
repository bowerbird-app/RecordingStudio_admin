# frozen_string_literal: true

module AdminScreens
  UserReviewsReviewVolumeWidget = RecordingStudioAdmin::Widget.new("widgets.user_reviews.review_volume") do
    type :chart
    title "Review queue"
    description "Review-needed user activity across the last fourteen days."
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
      UserActivity.where(status: "review", created_at: range).count
    end
    change { |_context| AdminScreens::Base.period_change_label(UserActivity.where(status: "review")) }
    chart_type :bar
    series do
      range = _1.widget_time_range || AdminScreens::Base.widget_preset_range(_1, preset_key: :this_week)
      [ {
        name: "Review queue",
        data: AdminScreens::Base.date_series(
          UserActivity.where(status: "review", created_at: range),
          bucket: _1.widget_group_by(default: :day)
        )
      } ]
    end
    chart_options { { height: 220 } }
    link_to do |context|
      AdminScreens::Base.widget_link_path(context, screen_key: "user_reviews", preset_key: :this_week)
    end
  end
end
