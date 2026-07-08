# frozen_string_literal: true

module RecordingStudioAdmin
  class AdminActivityLogsScreen < RecordingStudioAdmin::Screen
    key "admin_activity_logs"
    icon :clipboard_document_list
    title "Admin activity logs"
    subtitle "Review admin CRUD changes and resource actions"
    blast_radius :site
    widget "widgets.admin_activity_logs.activity_overview"

    query { |_context| audit_log_model.all }
    filter :date_range, field: :occurred_at, default: :last_30_days
    filter :group_by, values: %i[hour day week month year], default: :day
    filter :outcome, options: -> { audit_log_model.distinct.order(:outcome).pluck(:outcome) }
    filter :resource_key, options: -> { audit_log_model.distinct.order(:resource_key).pluck(:resource_key) }

    summary do
      label "Admin events"
      change_good_when :up
    end

    chart do
      title "Activity over time"
      type :area
      series do |context|
        [{
          name: "Admin events",
          data: RecordingStudioAdmin::AdminActivityLogsSupport.date_series(
            context.query_result.relation,
            field: :occurred_at,
            bucket: context.filter_value(:group_by) || :day
          )
        }]
      end
    end

    table do
      filter :search, apply: lambda { |relation, value, _context|
        if value.present?
          query = [
            "resource_key ILIKE :q OR action_key ILIKE :q OR outcome ILIKE :q",
            "actor_type ILIKE :q OR record_type ILIKE :q OR request_id ILIKE :q"
          ].join(" OR ")

          relation.where(
            query,
            q: RecordingStudioAdmin::AdminActivityLogsSupport.safe_like(value)
          )
        else
          relation
        end
      }

      column :occurred_at
      column :actor,
             sortable: false,
             value: ->(row, _context) { RecordingStudioAdmin::AdminActivityLogsScreen.actor_label(row) }
      column :admin_action,
             title: "Action",
             sortable: false,
             value: ->(row, _context) { RecordingStudioAdmin::AdminActivityLogsScreen.action_label(row) }
      column :record,
             sortable: false,
             value: ->(row, _context) { RecordingStudioAdmin::AdminActivityLogsScreen.record_label(row) }
      column :error_message, title: "Error", sortable: false
      column :outcome,
             display: :badge,
             display_options: lambda { |_row, _context, value|
               {
                 text: value.to_s.humanize,
                 style: RecordingStudioAdmin::AdminActivityLogsScreen.outcome_badge_style(value),
                 size: :sm
               }
             }

      default_sort :occurred_at, direction: :desc
      paginate per_page: 25
    end

    class << self
      def audit_log_model
        return ::AdminAuditLog if defined?(::AdminAuditLog)

        raise RecordingStudioAdmin::DefinitionNotFound,
              "Admin activity logs require an AdminAuditLog model in the host app"
      end

      def action_label(log)
        "#{log.resource_key}.#{log.action_key}"
      end

      def actor_label(log)
        polymorphic_label(log.actor_type, log.actor_id)
      end

      def record_label(log)
        polymorphic_label(log.record_type, log.record_id)
      end

      def outcome_badge_style(outcome)
        case outcome.to_s
        when "performed"
          :success
        when "validation_failed"
          :warning
        when "failed", "denied"
          :danger
        else
          :default
        end
      end

      private

      def polymorphic_label(type, id)
        return "System" if type.blank? && id.blank?
        return type if id.blank?

        "#{type} ##{id}"
      end
    end
  end
end
