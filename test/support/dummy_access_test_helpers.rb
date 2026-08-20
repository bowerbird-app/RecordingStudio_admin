# frozen_string_literal: true

module DummyAccessTestHelpers
  ROLE_RANK = {
    "view" => 1,
    "edit" => 2,
    "admin" => 3
  }.freeze

  def grant_admin_access_for_test!(recording:, actor:, role: :admin)
    current_role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
    return if role_covers?(current_role, role)

    if role.to_sym == :admin
      bootstrap_result = RecordingStudioAccessible.bootstrap_owner_access!(
        recording: recording,
        actor: actor
      )
      return if bootstrap_result.success?
    end

    previous_access_authorizer = RecordingStudioAccessible.configuration.access_management_authorizer
    begin
      RecordingStudioAccessible.configuration.access_management_authorizer = ->(recording:, **) { recording.present? }

      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: role,
        manager_actor: actor
      )

      raise "Failed to grant access in test: #{result.error}" if result.failure?
    ensure
      RecordingStudioAccessible.configuration.access_management_authorizer = previous_access_authorizer
    end
  end

  private

  def role_covers?(current_role, required_role)
    return false if current_role.nil?

    (ROLE_RANK[current_role.to_s] || 0) >= (ROLE_RANK[required_role.to_s] || 0)
  end
end
