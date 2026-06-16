# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class RootSwitchDropdownTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  test "home page renders the root switch dropdown trigger" do
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
    assert_includes response.body, "Recording Studio Admin Demo"
    assert_includes response.body, "Quickly create admin screens and dashboards using recording studio"
    assert_includes response.body, ">Admin root<"
    assert_includes response.body, ">Admin sections<"
    assert_includes response.body, ">Admin section dashboard<"
    assert_includes response.body, 'href="http://www.example.com/admin?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="http://www.example.com/admin/root?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="http://www.example.com/admin/sections?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_operator response.body.index("Admin root"), :<, response.body.index("Admin sections")
    assert_operator response.body.index("Admin sections"), :<, response.body.index("Admin section dashboard")
    refute_includes response.body, "What's working"
    refute_includes response.body, "Next steps"
    assert_includes response.body, workspace.name
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
end
