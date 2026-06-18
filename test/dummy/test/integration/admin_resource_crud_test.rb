# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminRegisteredActionsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  def setup
    @admin_user = User.find_or_create_by!(email: "admin-registered-actions@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    grant_admin_access_for_test!(recording: admin_root_recording_for_test, actor: @admin_user)
    sign_in @admin_user
  end

  test "admin can edit users through registered admin actions backed by host controllers" do
    managed_user = User.create!(
      email: "admin-action-managed-user@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )
    UserActivity.create!(
      email: managed_user.email,
      action: "signed_in",
      status: "review",
      created_at: Time.current
    )

    get "/admin/screens/users"
    assert_response :success
    assert_includes response.body, managed_user.email
    assert_includes response.body, "Show"
    assert_includes response.body, "Edit user"
    assert_includes response.body, "Flag email"
    assert_includes response.body, "/admin/users/#{managed_user.id}"
    assert_includes response.body, "/admin/users/#{managed_user.id}/edit"
    assert_includes response.body, "/admin/users/#{managed_user.id}/flag_email"

    get "/admin/users/#{managed_user.id}"
    assert_response :success
    assert_includes response.body, "User details"
    assert_includes response.body, "admin-action-managed-user@example.com"

    get "/admin/users/#{managed_user.id}/edit"
    assert_response :success
    assert_includes response.body, "Edit user"
    assert_includes response.body, "admin-action-managed-user@example.com"

    with_admin_action_events do |events|
      patch "/admin/users/#{managed_user.id}", params: {
        user: {
          email: "updated-admin-action-user@example.com",
          encrypted_password: "not permitted"
        }
      }

      assert_redirected_to "/admin/screens/users"
      assert_equal "updated-admin-action-user@example.com", managed_user.reload.email
      refute_equal "not permitted", managed_user.encrypted_password
      assert_equal "update", events.last.action_key
      assert_equal "performed", events.last.outcome
      assert_includes events.last.metadata.fetch(:changes).keys, "email"
    end

    with_admin_action_events do |events|
      post "/admin/users/#{managed_user.id}/flag_email"

      assert_redirected_to "/admin/screens/users"
      assert_equal "flagged-#{managed_user.id}@example.com", managed_user.reload.email
      assert_equal "flag_email", events.last.action_key
      assert_equal "performed", events.last.outcome
    end
  end

  test "host admin actions are forbidden when the current root is outside the admin surface" do
    workspace = Workspace.create!(name: "Resource Guard Workspace")
    workspace_root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: workspace_root_recording, actor: @admin_user)

    switch_to_root!(workspace_root_recording)

    managed_user = User.create!(
      email: "resource-guard-user@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    get "/admin/users/#{managed_user.id}/edit"
    assert_response :forbidden

    get "/admin/users/#{managed_user.id}"
    assert_response :forbidden

    post "/admin/users/#{managed_user.id}/flag_email"
    assert_response :forbidden
  end

  test "view-only users can use read actions but not registered mutation actions" do
    view_only_user = User.find_or_create_by!(email: "view-only-registered-actions@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    grant_admin_access_for_test!(recording: admin_root_recording_for_test, actor: view_only_user, role: :view)
    sign_out @admin_user
    sign_in view_only_user

    managed_user = User.create!(
      email: "view-only-managed-user@example.com",
      password: "Password123!",
      password_confirmation: "Password123!"
    )

    get "/admin/screens/users"
    assert_response :success
    assert_includes response.body, managed_user.email
    assert_includes response.body, "Show"
    assert_includes response.body, "/admin/users/#{managed_user.id}"
    refute_includes response.body, "Edit user"
    refute_includes response.body, "Flag email"
    refute_includes response.body, "/admin/users/#{managed_user.id}/edit"
    refute_includes response.body, "/admin/users/#{managed_user.id}/flag_email"

    get "/admin/users/#{managed_user.id}"
    assert_response :success
    assert_includes response.body, "User details"
    assert_includes response.body, managed_user.email
    refute_includes response.body, "/admin/users/#{managed_user.id}/edit"

    get "/admin/users/#{managed_user.id}/edit"
    assert_response :forbidden

    patch "/admin/users/#{managed_user.id}", params: { user: { email: "blocked-view-only-update@example.com" } }
    assert_response :forbidden
    assert_equal "view-only-managed-user@example.com", managed_user.reload.email

    post "/admin/users/#{managed_user.id}/flag_email"
    assert_response :forbidden
    assert_equal "view-only-managed-user@example.com", managed_user.reload.email
  end

  private

  def switch_to_root!(root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: "/"
      }
    }
    follow_redirect!
  end

  def admin_root_recording_for_test
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end

  def with_admin_action_events
    previous_auditor = RecordingStudioAdmin.configuration.admin_action_auditor
    events = []
    RecordingStudioAdmin.configuration.admin_action_auditor = ->(event) { events << event }
    yield events
  ensure
    RecordingStudioAdmin.configuration.admin_action_auditor = previous_auditor
  end
end