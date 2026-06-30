# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class StatsRootTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  def sign_in_stats_user(email: "stats-root-test@example.com")
    user = User.find_or_create_by!(email: email) do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    sign_in user
    user
  end

  def switch_to_workspace_root!(workspace_root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: workspace_root_recording.id,
        return_to: "/"
      }
    }
    follow_redirect!
  end

  def record_child_for_test!(recordable:, root_recording:, parent_recording:, actor:, created_at:)
    previous_actor = Current.actor
    Current.actor = actor

    recording = RecordingStudio::Recording.find_by(
      root_recording: root_recording,
      parent_recording: parent_recording,
      recordable: recordable,
      trashed_at: nil
    ) || RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording
    ).recording

    recordable.class.where(id: recordable.id).update_all(created_at: created_at, updated_at: created_at)
    recording.update_columns(created_at: created_at, updated_at: created_at)
    recording
  ensure
    Current.actor = previous_actor
  end

  test "stats root shows available sections for workspace roots" do
    user = sign_in_stats_user

    workspace = Workspace.create!(name: "Stats Workspace")
    workspace_root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: workspace_root_recording, actor: user)

    switch_to_workspace_root!(workspace_root_recording)

    get "/stats/root"

    assert_response :success
    assert_includes response.body, "Stats"
    assert_includes response.body, "Track workspace content and recording activity"
    assert_includes response.body, 'href="/stats/sections/stats?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
  end

  test "stats section and screen render workspace content demo" do
    user = sign_in_stats_user(email: "stats-demo-test@example.com")

    workspace = Workspace.create!(name: "Workspace Stats Demo")
    workspace_root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: workspace_root_recording, actor: user)

    analytics_folder = Folder.create!(name: "Demo Analytics")
    analytics_folder_recording = record_child_for_test!(
      recordable: analytics_folder,
      root_recording: workspace_root_recording,
      parent_recording: workspace_root_recording,
      actor: user,
      created_at: 3.days.ago
    )
    onboarding_folder = Folder.create!(name: "Demo Onboarding")
    record_child_for_test!(
      recordable: onboarding_folder,
      root_recording: workspace_root_recording,
      parent_recording: workspace_root_recording,
      actor: user,
      created_at: 2.days.ago
    )

    kpi_page = Page.create!(title: "Demo KPI Dashboard")
    record_child_for_test!(
      recordable: kpi_page,
      root_recording: workspace_root_recording,
      parent_recording: analytics_folder_recording,
      actor: user,
      created_at: 1.day.ago
    )

    switch_to_workspace_root!(workspace_root_recording)

    get "/stats/sections/stats", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Stats"
    assert_includes response.body, "Track workspace content and recording activity"
    assert_includes response.body, "View stats"
    assert_includes response.body, 'href="/stats/screens/workspace_stats?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "Total items"
    assert_includes response.body, "Pages"
    assert_includes response.body, "Folders"
    assert_includes response.body, "Content activity"

    get "/stats/screens/workspace_stats", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Workspace stats"
    assert_includes response.body, "Review folders, pages, and recording activity for the current workspace"
    assert_includes response.body, 'id="screen-chart" src="/stats/screens/workspace_stats/chart?anchor_url='

    get "/stats/screens/workspace_stats/chart", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Content created over time"
    assert_includes response.body, 'data-controller="flat-pack--chart"'

    get "/stats/screens/workspace_stats/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Demo Analytics"
    assert_includes response.body, "Demo Onboarding"
    assert_includes response.body, "Demo KPI Dashboard"
    assert_includes response.body, ">Folder<"
    assert_includes response.body, ">Page<"
  end

  test "stats section and screen are not available for admin roots" do
    user = sign_in_stats_user(email: "stats-admin-root-guard@example.com")

    workspace = Workspace.create!(name: "Admin Guard Workspace")
    workspace_root_recording = RecordingStudio.root_recording_for(workspace)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)

    grant_admin_access_for_test!(recording: workspace_root_recording, actor: user)
    grant_admin_access_for_test!(recording: admin_root_recording, actor: user)

    switch_to_workspace_root!(admin_root_recording)

    get "/stats/sections/stats", params: { anchor_url: root_url }

    assert_response :not_found

    get "/stats/screens/workspace_stats", params: { anchor_url: root_url }

    assert_response :not_found
  end
end
