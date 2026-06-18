# frozen_string_literal: true

module RecordingStudioAdmin
  module Authorization
    module_function

    def authorize!(context, recording: context.access_recording, role: RecordingStudioAdmin.configuration.required_access_role)
      ensure_recording_studio_accessible_available!
      raise AuthorizationFailed, "RecordingStudioAdmin access recording is not configured" unless recording

      actor = context.current_actor
      raise AuthorizationFailed, "RecordingStudioAdmin current actor is not configured" unless actor

      ensure_current_root_matches!(context, recording)

      return true if ::RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: recording,
        role: role
      )

      raise AuthorizationFailed, "Current actor cannot access RecordingStudioAdmin recording"
    end

    def ensure_recording_studio_accessible_available!
      return if defined?(::RecordingStudioAccessible)

      raise AuthorizationFailed,
            "RecordingStudioAccessible is not available"
    end

    def ensure_current_root_matches!(context, recording)
      current_root_recording = resolve_current_root_recording(context)
      return true unless current_root_recording

      target_root_recording = resolve_root_recording(recording)
      return true if current_root_recording == target_root_recording

      raise AuthorizationFailed, "Current root does not match RecordingStudioAdmin access root"
    end

    def resolve_current_root_recording(context)
      controller = context.controller
      return controller.send(:current_root_recording) if controller && controller.respond_to?(:current_root_recording, true)

      return ::RecordingStudio::RootSwitchable.current_root_recording if defined?(::RecordingStudio::RootSwitchable)

      nil
    end

    def resolve_root_recording(recording)
      return recording.root_recording if recording.respond_to?(:root_recording) && recording.root_recording
      return ::RecordingStudio.root_recording_or_self(recording) if defined?(::RecordingStudio) && recording.respond_to?(:root_recording)

      recording
    end
  end
end
