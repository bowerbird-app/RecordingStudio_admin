# frozen_string_literal: true

module DummyAccessTestHelpers
  def grant_admin_access_for_test!(recording:, actor:)
    previous_access_authorizer = RecordingStudioAccessible.configuration.access_management_authorizer
    RecordingStudioAccessible.configuration.access_management_authorizer = ->(recording:, **) { recording.present? }

    result = RecordingStudioAccessible.grant_access(
      recording: recording,
      actor: actor,
      role: :admin,
      manager_actor: actor
    )

    raise "Failed to grant access in test: #{result.error}" if result.failure?
  ensure
    RecordingStudioAccessible.configuration.access_management_authorizer = previous_access_authorizer
  end
end
