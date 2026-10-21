# frozen_string_literal: true

module RecordingStudioAdmin
  module LogsRegistration
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

    def source_model_name
      RecordingStudioAdmin.configuration.audit_log_model.to_s
    end

    def source_class
      source_model_name.safe_constantize
    end

    def resolved_retention
      :indefinite
    end

    def register!
      return unless defined?(RecordingStudioLogs)
      return if source_model_name.blank?

      register_source!
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
  end
end
