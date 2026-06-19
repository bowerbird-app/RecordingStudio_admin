# frozen_string_literal: true

module RecordingStudioAdmin
  AdminActivityLogsActivityOverview = RecordingStudioAdmin::Widget.new(
    nil,
    registry_prefix: "admin_activity_logs.widgets.activity_overview",
    blast_radius: :site
  ) do
    type :chart
    title "Admin activity overview"
    description "Seven-day admin event volume with the current period total and percentage change."
    metadata do |context|
      {
        period_label: RecordingStudioAdmin::AdminActivityLogsSupport.widget_preset_label(
          context,
          preset_key: :this_week,
          fallback: "This week"
        )
      }
    end
    value do |context|
      range = context.widget_time_range || RecordingStudioAdmin::AdminActivityLogsSupport.widget_preset_range(
        context,
        preset_key: :this_week
      )
      RecordingStudioAdmin::AdminActivityLogsScreen.audit_log_model.where(occurred_at: range).count
    end
    change do |_context|
      RecordingStudioAdmin::AdminActivityLogsSupport.period_change_label(
        RecordingStudioAdmin::AdminActivityLogsScreen.audit_log_model.all,
        field: :occurred_at,
        current_period: 7.days.ago..,
        previous_period: 14.days.ago...7.days.ago
      )
    end
    chart_type :area
    series do |context|
      range = context.widget_time_range || RecordingStudioAdmin::AdminActivityLogsSupport.widget_preset_range(
        context,
        preset_key: :this_week
      )
      [{
        name: "Admin events",
        data: RecordingStudioAdmin::AdminActivityLogsSupport.date_series(
          RecordingStudioAdmin::AdminActivityLogsScreen.audit_log_model.where(occurred_at: range).reorder(nil),
          field: :occurred_at,
          bucket: context.widget_group_by(default: :day)
        )
      }]
    end
    chart_options { { height: 220 } }
    link_to do |context|
      RecordingStudioAdmin::AdminActivityLogsSupport.widget_link_path(
        context,
        screen_key: "admin_activity_logs",
        preset_key: :this_week
      )
    end
  end
end
