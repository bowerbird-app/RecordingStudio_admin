# frozen_string_literal: true

module RecordingStudioAdmin
  module Authorization
    module_function

    def authorize!(context, recording: context.access_recording)
      ensure_recording_studio_accessible_available!
      raise AuthorizationFailed, "RecordingStudioAdmin access recording is not configured" unless recording

      actor = context.current_actor
      raise AuthorizationFailed, "RecordingStudioAdmin current actor is not configured" unless actor

      return true if ::RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: RecordingStudioAdmin.configuration.required_access_role
      )

      raise AuthorizationFailed, "Current actor cannot access RecordingStudioAdmin recording"
    end

    def ensure_recording_studio_accessible_available!
      return if defined?(::RecordingStudioAccessible)

      raise AuthorizationFailed,
            "RecordingStudioAccessible is not available"
    end
  end
end
