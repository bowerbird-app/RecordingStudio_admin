# frozen_string_literal: true

require "securerandom"

module RecordingStudioAdmin
  AdminActionAuditEvent = Data.define(:id, :resource_key, :action_key, :outcome, :actor, :record, :access_recording,
                                      :surface_key, :http_method, :destructive, :required_role, :blast_radius,
                                      :request_id, :ip_address, :user_agent, :metadata, :error_class, :error_message,
                                      :recording_studio_event) do
    def to_h
      {
        id: id,
        resource_key: resource_key,
        action_key: action_key,
        outcome: outcome,
        actor: actor,
        record: record,
        access_recording: access_recording,
        surface_key: surface_key,
        http_method: http_method,
        destructive: destructive,
        required_role: required_role,
        blast_radius: blast_radius,
        request_id: request_id,
        ip_address: ip_address,
        user_agent: user_agent,
        metadata: metadata,
        error_class: error_class,
        error_message: error_message,
        recording_studio_event: recording_studio_event
      }
    end
  end

  module AdminActionAudit
    NOTIFICATION_NAME = "admin_action.recording_studio_admin"

    module_function

    def build(resource_key:, action_key:, context:, record:, outcome:, action_definition: nil, metadata: {}, error: nil,
              id: SecureRandom.uuid, recording_studio_event: nil)
      action_definition ||= RecordingStudioAdmin.resource_for(resource_key)&.action_for(action_key)
      controller = context.controller
      request = controller.request if controller&.respond_to?(:request)

      AdminActionAuditEvent.new(
        id,
        resource_key.to_s,
        action_key.to_s,
        outcome.to_s,
        context.current_actor,
        record,
        context.access_recording,
        context.surface&.key,
        action_definition&.method,
        action_definition&.destructive,
        action_definition&.required_access_role,
        action_definition&.blast_radius,
        request&.request_id,
        request&.remote_ip,
        request&.user_agent,
        metadata.compact,
        error&.class&.name,
        error&.message,
        recording_studio_event
      )
    end

    def record(**attributes)
      event = build(**attributes)
      ActiveSupport::Notifications.instrument(NOTIFICATION_NAME, event.to_h) if defined?(ActiveSupport::Notifications)
      RecordingStudioAdmin.configuration.admin_action_auditor&.call(event)
      event
    end

    class Tracker
      attr_reader :id

      def initialize(resource_key:, action_key:, context:, record:, action_definition:, metadata: {})
        @id = SecureRandom.uuid
        @resource_key = resource_key
        @action_key = action_key
        @context = context
        @record = record
        @action_definition = action_definition
        @metadata = metadata
        @recording_studio_event = nil
      end

      def recording_studio_event(recordable:, action:, metadata: {}, **attributes)
        raise RecordingStudioAdmin::Error, "RecordingStudio is not available" unless defined?(::RecordingStudio)

        event_metadata = metadata.merge(admin_audit_event_id: id)
        root_recording = default_root_recording
        parent_recording = default_parent_recording
        attributes[:root_recording] ||= root_recording if root_recording
        attributes[:parent_recording] ||= parent_recording if parent_recording
        attributes[:metadata] = event_metadata if event_metadata.any?
        @recording_studio_event = ::RecordingStudio.record!(action: action, recordable: recordable, **attributes)
      end

      def record(outcome:, metadata: {}, error: nil)
        RecordingStudioAdmin::AdminActionAudit.record(
          id: id,
          resource_key: @resource_key,
          action_key: @action_key,
          context: @context,
          record: @record,
          outcome: outcome,
          action_definition: @action_definition,
          metadata: @metadata.merge(record_changes).merge(metadata),
          error: error,
          recording_studio_event: @recording_studio_event
        )
      end

      private

      def record_changes
        return {} unless @record.respond_to?(:previous_changes)

        changes = @record.previous_changes.except("updated_at")
        changes.any? ? { changes: changes } : {}
      end

      def default_root_recording
        return unless @context.respond_to?(:root_recording)

        @context.root_recording
      rescue StandardError
        nil
      end

      def default_parent_recording
        return unless @context.respond_to?(:access_recording)

        @context.access_recording
      rescue StandardError
        nil
      end
    end
  end

  module AdminActionAuditing
    private

    def perform_recording_studio_admin_action!(resource_key, action_key, record, audit_action: nil, metadata: {})
      action_definition = RecordingStudioAdmin.authorize_resource!(
        key: resource_key,
        action: action_key,
        context: recording_studio_admin_context,
        record: record,
        audit: true,
        audit_action: audit_action
      )
      tracker = RecordingStudioAdmin::AdminActionAudit::Tracker.new(
        resource_key: resource_key,
        action_key: audit_action || action_key,
        context: recording_studio_admin_context,
        record: record,
        action_definition: action_definition,
        metadata: metadata
      )

      result = yield tracker
      tracker.record(outcome: result == false ? :validation_failed : :performed)
      result
    rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
      raise
    rescue StandardError => error
      tracker&.record(outcome: :failed, error: error)
      raise
    end
  end
end