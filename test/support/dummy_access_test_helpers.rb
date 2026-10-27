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

    manager = existing_test_access_manager(recording, role)
    manager = bootstrap_test_access_manager!(recording) if manager.nil? && role.to_sym != :admin
    raise "Failed to grant access in test: no manager holds #{role}" if manager.nil?

    previous_access_authorizer = RecordingStudioAccessible.configuration.access_management_authorizer
    begin
      RecordingStudioAccessible.configuration.access_management_authorizer = ->(recording:, **) { recording.present? }

      result = RecordingStudioAccessible.grant_access(
        recording: recording,
        actor: actor,
        role: role,
        manager_actor: manager
      )

      raise "Failed to grant access in test: #{result.error}" if result.failure?
    ensure
      RecordingStudioAccessible.configuration.access_management_authorizer = previous_access_authorizer
    end
  end

  private

  def existing_test_access_manager(recording, role)
    RecordingStudioAccessible.access_recordings_for(recording).each do |access_recording|
      access = access_recording.recordable
      next unless access.respond_to?(:actor) && access.actor
      next unless role_covers?(access.role, role)

      held = RecordingStudioAccessible.role_for(actor: access.actor, recording: recording)
      return access.actor if role_covers?(held, role)
    end

    nil
  end

  def bootstrap_test_access_manager!(recording)
    manager = User.find_or_create_by!(email: "recording-studio-admin-grant-manager@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    bootstrap = RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: manager)
    raise "Failed to bootstrap test access manager: #{bootstrap.error}" if bootstrap.failure?

    manager
  end

  def role_covers?(current_role, required_role)
    return false if current_role.nil?

    (ROLE_RANK[current_role.to_s] || 0) >= (ROLE_RANK[required_role.to_s] || 0)
  end
end
