# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class FilterAllowedValuesContextTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  test "zero-arg filter options still resolve on a live admin screen" do
    sign_in_admin_user
    ApiRequest.delete_all
    ApiRequest.create!(path: "/v1/ok", method: "GET", status: 200, latency_ms: 11, created_at: 2.minutes.ago,
                       updated_at: 2.minutes.ago)
    ApiRequest.create!(path: "/v1/fail", method: "POST", status: 500, latency_ms: 44, created_at: 1.minute.ago,
                       updated_at: 1.minute.ago)

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    refute_includes response.body, "ArgumentError"
    assert_equal expected_api_status_values, filter_option_values("status")
  end

  test "filter dropdown options match table distinct values for the current root" do
    user = sign_in_admin_user
    folder_root = workspace_with_only_folders!(actor: user)
    page_root = workspace_with_only_pages!(actor: user)

    switch_to_root!(folder_root)
    assert_item_types_match_table!(expected_types: [ "Folder" ], expected_items: [ "Folders only" ])

    switch_to_root!(page_root)
    assert_item_types_match_table!(expected_types: [ "Page" ], expected_items: [ "Pages only" ])
  end

  private

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "filter-allowed-values@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    grant_admin_access_for_test!(recording: admin_root_recording_for_test, actor: user)
    sign_in user
    user
  end

  def admin_root_recording_for_test
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end

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

  def workspace_with_only_folders!(actor:)
    workspace = Workspace.create!(name: "Folders workspace #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: actor)
    record_child_for_test!(
      recordable: Folder.create!(name: "Folders only"),
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
    )
    root_recording
  end

  def workspace_with_only_pages!(actor:)
    workspace = Workspace.create!(name: "Pages workspace #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: actor)
    record_child_for_test!(
      recordable: Page.create!(title: "Pages only"),
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
    )
    root_recording
  end

  def record_child_for_test!(recordable:, root_recording:, parent_recording:, actor:)
    previous_actor = Current.actor
    Current.actor = actor
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording,
      actor: actor
    ).recording
  ensure
    Current.actor = previous_actor
  end

  def assert_item_types_match_table!(expected_types:, expected_items:)
    get "/stats/screens/item_types", params: { anchor_url: root_url }

    assert_response :success
    refute_includes response.body, "ArgumentError"
    option_values = filter_option_values("type")

    get "/stats/screens/item_types/table", params: { anchor_url: root_url }

    assert_response :success
    table_types = css_select("#screen-table tbody tr").map do |row|
      row.css("td").first&.text&.strip
    end.compact.uniq.sort
    table_items = expected_items.select { |item| response.body.include?(item) }

    assert_equal expected_types, option_values
    assert_equal expected_types, table_types
    assert_equal option_values, table_types
    assert_equal expected_items, table_items
  end

  def expected_api_status_values
    ApiRequest.distinct.order(:status).pluck(:status).map(&:to_s)
  end

  def filter_option_values(param_name)
    native_values = css_select(%(select[name="#{param_name}"] option)).filter_map do |option|
      option["value"].presence
    end
    return native_values.uniq.sort if native_values.any?

    css_select(%([data-controller~="flat-pack--select"])).each do |wrapper|
      named = wrapper.css(%([name="#{param_name}"]))
      next if named.empty?

      option_values = wrapper.css(%([role="option"][data-value])).filter_map do |node|
        node["data-value"].presence
      end
      return option_values.uniq.sort if option_values.any?
    end

    []
  end
end
