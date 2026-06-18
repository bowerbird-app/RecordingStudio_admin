# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  test "home page shows workspace view for non-admin roots" do
    user = User.find_or_create_by!(email: "root-switch-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Dropdown Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: user)

    get root_path

    assert_response :success
    assert_includes response.body, "Workspace Home"
    assert_includes response.body, "Quickly create admin screens and dashboards using recording studio"
    assert_includes response.body, ">Stats<"
    assert_includes response.body, 'href="http://www.example.com/stats/root?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    refute_includes response.body, "Admin Root Home"
    refute_includes response.body, 'href="http://www.example.com/admin/root?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    refute_includes response.body, 'href="http://www.example.com/admin?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    refute_includes response.body, ">Manage admin sections<"
    refute_includes response.body, "What's working"
    refute_includes response.body, "Next steps"
    assert_includes response.body, workspace.name
  end

  test "home page shows admin-root view for admin roots" do
    user = User.find_or_create_by!(email: "root-switch-admin-home-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    grant_admin_access_for_test!(recording: admin_root_recording, actor: user)

    get root_path

    assert_response :success
    assert_includes response.body, "Admin Root Home"
    assert_includes response.body, "You are viewing admin-root specific controls and navigation."
    assert_includes response.body, ">Admin root<"
    assert_includes response.body, ">Manage admin sections<"
    refute_includes response.body, ">Stats<"
    refute_includes response.body, "Workspace Home"
    refute_includes response.body, ">Admin section dashboard<"
  end

  test "root switch page renders with the host sidebar" do
    user = User.find_or_create_by!(email: "root-switch-page-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Switch Page Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: user)

    get "/recording_studio_root_switchable/v1/root_switch?scope=all_workspaces"

    assert_response :success
    assert_includes response.body, "Install"
  end

  test "switching returns to the current page when it is a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-redirect-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Source Workspace")
    target_workspace = Workspace.create!(name: "Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    source_root_recording = RecordingStudio.root_recording_for(source_workspace)
    grant_admin_access_for_test!(recording: source_root_recording, actor: user)
    grant_admin_access_for_test!(recording: target_root_recording, actor: user)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/docs/install"
      }
    }

    assert_redirected_to "/docs/install"
  end

  test "switching falls back to home when return_to is not a valid internal route" do
    user = User.find_or_create_by!(email: "root-switch-fallback-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    source_workspace = Workspace.create!(name: "Fallback Source Workspace")
    target_workspace = Workspace.create!(name: "Fallback Target Workspace")
    target_root_recording = RecordingStudio.root_recording_for(target_workspace)
    source_root_recording = RecordingStudio.root_recording_for(source_workspace)
    grant_admin_access_for_test!(recording: source_root_recording, actor: user)
    grant_admin_access_for_test!(recording: target_root_recording, actor: user)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: target_root_recording.id,
        return_to: "/not-a-real-route"
      }
    }

    assert_redirected_to "/"
  end

  test "admin routes are forbidden when the current root is a workspace" do
    user = User.find_or_create_by!(email: "root-switch-admin-guard-test@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user

    workspace = Workspace.create!(name: "Guarded Workspace")
    workspace_root_recording = RecordingStudio.root_recording_for(workspace)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    grant_admin_access_for_test!(recording: workspace_root_recording, actor: user)
    grant_admin_access_for_test!(recording: admin_root_recording, actor: user)

    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: workspace_root_recording.id,
        return_to: "/"
      }
    }
    follow_redirect!

    get "/admin"

    assert_response :forbidden

    get "/admin/root"

    assert_response :forbidden
  end
end
