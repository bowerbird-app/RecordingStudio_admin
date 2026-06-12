# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "cgi"

class AdminSectionRenderingTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "admin-section-rendering@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    workspace = Workspace.create!(name: "Admin Rendering Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: user)

    sign_in user
  end

  test "admin root section renders without the old custom layout wrappers" do
    sign_in_admin_user

    get "/admin", params: { anchor_url: root_url }

    admin_root = AdminRoot.find_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    admin_summary_section = AdminSummarySection.find_by!(key: "root")
    admin_summary_recording = RecordingStudio::Recording.find_by!(recordable: admin_summary_section)

    assert_response :success
    assert_includes response.body, "Admin summary"
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, "View API requests"
    assert_includes response.body, 'href="/admin/screens/api_requests?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "API activity"
    assert_includes response.body, "Recent failures"
    assert_includes response.body, "Active users"
    assert_includes response.body, "Job throughput"
    assert_includes response.body, "Recent request paths"
    body = CGI.unescapeHTML(response.body)
    assert_equal 4, body.scan("data-flat-pack--chart-series-value=").size
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"API activity"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Recent failures"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Active users"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Job throughput"'
    refute_includes response.body, "--button-primary-background-color"
    refute_includes response.body, "flex flex-wrap gap-2 my-4"
    refute_includes response.body, "grid gap-4 md:grid-cols-2 xl:grid-cols-4"
    assert_equal admin_root_recording, admin_summary_recording.root_recording
    assert_equal admin_root_recording, admin_summary_recording.parent_recording
  end

  test "admin screen renders streamlined filters with table results" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "API requests"
    assert_includes response.body, "Requests over time"
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, 'name="anchor_url"'
    assert_includes response.body, 'value="http://www.example.com/"'
    assert_includes response.body, "Table data"
    assert_includes response.body, "Created at"
    assert_includes response.body, "Latency"
    assert_includes response.body, "sort=created_at"
    assert_includes response.body, "bg-[var(--badge-success-background-color)]"
    assert_includes response.body, 'data-controller="flat-pack--timestamp"'
    assert_includes response.body, 'data-controller="flat-pack--auto-submit"'
    assert_includes response.body, 'data-turbo-frame="screen-chart"'
    assert_includes response.body, 'data-pagination-content="true"'
    assert_includes response.body, 'data-controller="flat-pack--pagination-infinite"'
    assert_includes response.body, 'data-flat-pack--pagination-infinite-url-value="/admin/screens/api_requests?anchor_url=http%3A%2F%2Fwww.example.com%2F&amp;page=2"'
    assert_includes response.body, 'id="screen-chart"'
    refute_includes response.body, "Apply filters"
    refute_includes response.body, "flex items-start justify-between gap-4 p-6"
    refute_includes response.body, "Filters"
    refute_includes response.body, "Group By"
    refute_includes response.body, "screen-results"
    refute_includes response.body, "my-4"
    refute_includes response.body, "mt-4"
  end

  test "admin screen chart turbo frame reloads with filtered data" do
    sign_in_admin_user

    get "/admin/screens/api_errors", headers: { "Turbo-Frame" => "screen-chart" }

    assert_response :success
    body = CGI.unescapeHTML(response.body)

    assert_includes body, 'id="screen-chart"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Errors"'
    assert_includes body, '"x":"'

    get "/admin/screens/api_errors", params: {
      start_date: 100.years.ago.to_date.iso8601,
      end_date: 90.years.ago.to_date.iso8601
    }, headers: { "Turbo-Frame" => "screen-chart" }

    assert_response :success
    body = CGI.unescapeHTML(response.body)

    assert_includes body, 'id="screen-chart"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Errors","data":[]}]"'
  end

  test "admin screen chart formats x labels for the selected group by bucket" do
    sign_in_admin_user
    ApiRequest.delete_all

    ApiRequest.create!(path: "/v1/alpha", method: "GET", status: 200, latency_ms: 12, created_at: Time.zone.local(2024, 1, 15, 10))
    ApiRequest.create!(path: "/v1/beta", method: "GET", status: 200, latency_ms: 14, created_at: Time.zone.local(2024, 2, 20, 11))
    ApiRequest.create!(path: "/v1/gamma", method: "GET", status: 200, latency_ms: 16, created_at: Time.zone.local(2025, 3, 5, 9))

    get "/admin/screens/api_requests", params: {
      start_date: "2024-01-01",
      end_date: "2025-12-31",
      group_by: "month"
    }, headers: { "Turbo-Frame" => "screen-chart" }

    assert_response :success
    body = CGI.unescapeHTML(response.body)

    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Requests","data":[{"x":"Jan","y":1},{"x":"Feb","y":1},{"x":"Mar","y":1}]}]"'

    get "/admin/screens/api_requests", params: {
      start_date: "2024-01-01",
      end_date: "2025-12-31",
      group_by: "year"
    }, headers: { "Turbo-Frame" => "screen-chart" }

    assert_response :success
    body = CGI.unescapeHTML(response.body)

    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Requests","data":[{"x":"2024","y":2},{"x":"2025","y":1}]}]"'
  end
end
