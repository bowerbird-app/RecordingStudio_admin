# frozen_string_literal: true

module RecordingStudioAdmin
  # Opt-in Metrics registration for the host's admin audit log (the AdminAuditLog
  # model and table from the admin_root generator). Admin does not depend on
  # RecordingStudioMetrics; hosts that bundle it (~> 0.3) call
  # RecordingStudioAdmin::Metrics.register!(model: AdminAuditLog) from to_prepare.
  module Metrics
    RESOURCE = :admin_events
    API = :operations
    EXPOSE = { api: [API] }.freeze
    GROUPS = %i[action_key resource_key outcome].freeze
    OVER_TIME_DESCRIPTION = "Audited admin actions by occurred_at. Group by action_key (paired with " \
                            "resource_key, since action keys repeat across resources) or outcome."
    ResolverContext = Struct.new(:controller)

    module_function

    def register!(model:)
      require "recording_studio_metrics"

      RecordingStudioMetrics.register(
        RESOURCE,
        model: model,
        blast_radius: :site,
        api_authorize: ->(context) { RecordingStudioAdmin::Metrics.can_view?(context) }
      ) { RecordingStudioAdmin::Metrics.define(self) }
    end

    def define(dsl)
      dsl.timeseries :over_time, title: "Admin actions over time", description: OVER_TIME_DESCRIPTION,
                                 unit: "count", field: :occurred_at, group_by: GROUPS, expose: EXPOSE
    end

    def can_view?(context)
      actor = context&.access_grant&.actor
      recording = admin_root_recording
      return false if actor.blank? || recording.blank? || !defined?(RecordingStudioAccessible)

      RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
    end

    def admin_root_recording
      config = RecordingStudioAdmin.configuration
      resolver = config.site_admin_recording_resolver || config.access_recording_resolver
      resolver&.call(ResolverContext.new(nil))
    rescue StandardError
      nil
    end
  end
end
