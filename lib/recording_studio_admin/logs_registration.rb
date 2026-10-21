# frozen_string_literal: true

module RecordingStudioAdmin
  module LogsRegistration
    AUDIT_COUNTS = "admin/audit_counts"
    OWNER = "RecordingStudioAdmin"
    FORBIDDEN_AGGREGATABLE = %i[
      actor_type actor_id ip_address user_agent request_id error_class error_message
    ].freeze
    AGGREGATABLE = {
      root_recording_id: { filter: [:eq], group: true },
      resource_key: { filter: [:eq], group: true },
      action_key: { filter: [:eq], group: true },
      outcome: { filter: [:eq], group: true }
    }.freeze

    module_function

    def summaries_enabled?
      RecordingStudioAdmin.configuration.logs_summaries_enabled
    end

    def source_model_name
      RecordingStudioAdmin.configuration.audit_log_model.to_s
    end

    def summary_model_name
      RecordingStudioAdmin.configuration.audit_day_summary_model.to_s
    end

    def source_class
      source_model_name.safe_constantize
    end

    def summary_class
      summary_model_name.safe_constantize
    end

    def logging_connection
      source_class&.connection || ActiveRecord::Base.connection
    end

    def resolved_retention
      retention = RecordingStudioAdmin.configuration.logs_retention
      return :indefinite if retention.blank? || retention == :indefinite

      retention
    end

    def register!
      return unless defined?(RecordingStudioLogs)
      return if source_model_name.blank?

      register_source!
      register_audit_counts!
      RecordingStudioLogs.finalize!
    end

    def register_source!
      RecordingStudioLogs.register(
        model: source_model_name,
        timestamp_column: :occurred_at,
        partition_interval: nil,
        root_column: :root_recording_id,
        owner: OWNER,
        retention: resolved_retention,
        aggregatable: AGGREGATABLE
      )
    end

    def register_audit_counts!
      RecordingStudioLogs.aggregate(
        source: source_model_name,
        name: AUDIT_COUNTS,
        summary_model: summary_model_name,
        owner: OWNER,
        group_by: %i[root_recording_id resource_key action_key outcome],
        measurements: {
          event_count: :count
        }
      )
    end

    def audit_counts_definition
      RecordingStudioLogs.registry.aggregation(AUDIT_COUNTS)
    end
  end
end
