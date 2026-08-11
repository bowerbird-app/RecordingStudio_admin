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

    grant_admin_access_for_test!(recording: admin_root_recording_for_test, actor: user)

    sign_in user
  end

  def sign_in_user_without_admin_access
    user = User.find_or_create_by!(email: "admin-no-access@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    admin_root_recording_for_test
    sign_in user
  end

  def admin_root_recording_for_test
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end

  test "admin root section renders without the old custom layout wrappers" do
    sign_in_admin_user
    original_async_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled
    RecordingStudioAdmin.configuration.async_widgets.enabled = false

    ApiError.delete_all
    ApiError.create!(error_class: "TimeoutError", message: "timeout", path: "/v1/timeout", status: 504, created_at: 2.minutes.ago, updated_at: 2.minutes.ago)
    ApiError.create!(error_class: "TimeoutError", message: "timeout again", path: "/v1/timeout", status: 504, created_at: 1.minute.ago, updated_at: 1.minute.ago)
    ApiError.create!(error_class: "ValidationError", message: "invalid payload", path: "/v1/payload", status: 422, created_at: 3.minutes.ago, updated_at: 3.minutes.ago)

    UserActivity.delete_all
    UserActivity.create!(email: "recent-user-1@example.com", action: "signed_in", status: "success", created_at: 1.minute.ago, updated_at: 1.minute.ago)
    UserActivity.create!(email: "recent-user-2@example.com", action: "exported_report", status: "review", created_at: 2.minutes.ago, updated_at: 2.minutes.ago)
    UserActivity.create!(email: "recent-user-3@example.com", action: "invited_user", status: "success", created_at: 3.minutes.ago, updated_at: 3.minutes.ago)

    get "/admin", params: { anchor_url: root_url }

    admin_root = AdminRoot.find_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    admin_section = AdminSection.find_by!(key: "root")
    admin_section_recording = RecordingStudio::Recording.find_by!(recordable: admin_section)

    assert_response :success
    assert_includes response.body, "Admin section"
    refute_includes response.body, 'data-flat-pack--icon-name-value="folder"'
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, "View API"
    assert_includes response.body, 'href="/admin/sections/api?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, ">More<"
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
    assert_includes response.body, "max-w-6xl"
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"
    refute_includes response.body, "Admin menu"
    assert_includes response.body, "Most common errors"
    assert_includes response.body, "View users"
    assert_includes response.body, 'href="/admin/sections/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "View jobs"
    assert_includes response.body, 'href="/admin/sections/jobs?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "API activity"
    refute_includes response.body, "Total API requests recorded during the last 24 hours."
    assert_includes response.body, "Recent failures"
    assert_includes response.body, "Most common errors"
    assert_includes response.body, "Active users"
    assert_includes response.body, "Review completion"
    assert_includes response.body, "2 / 3 reviewed"
    assert_includes response.body, 'role="progressbar"'
    refute_includes response.body, "Last 14 days"
    assert_includes response.body, "Most recent users"
    assert_includes response.body, "recent-user-1@example.com"
    assert_includes response.body, "recent-user-2@example.com"
    assert_includes response.body, "recent-user-3@example.com"
    assert_includes response.body, 'data-flat-pack--icon-name-value="user-circle"'
    assert_includes response.body, 'href="/users/recent-user-1-example-com"'
    assert_includes response.body, 'href="/users/recent-user-2-example-com"'
    assert_includes response.body, 'href="/users/recent-user-3-example-com"'
    assert_includes response.body, "hover:bg-[var(--list-item-hover-background-color)]"
    assert_includes response.body, "Job throughput"
    assert_includes response.body, "API activity (column)"
    assert_includes response.body, "API status split (donut)"
    assert_includes response.body, "API status spread (radar)"
    assert_includes response.body, "API success rate (gauge)"
    body = CGI.unescapeHTML(response.body)
    assert_operator body.scan("data-flat-pack--chart-series-value=").size, :>=, 4
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"API activity"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Recent failures"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Active users"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Job throughput"'
    assert_includes body, 'data-flat-pack--chart-series-value="[2,1]"'
    assert_operator body.scan('data-flat-pack--chart-type-value="pie"').size, :>=, 2
    column_like_count = body.scan('data-flat-pack--chart-type-value="column"').size +
              body.scan('data-flat-pack--chart-type-value="bar"').size
    assert_operator column_like_count, :>=, 1
    assert_operator body.scan('data-flat-pack--chart-type-value="donut"').size, :>=, 1
    assert_operator body.scan('data-flat-pack--chart-type-value="radar"').size, :>=, 2
    assert_includes body, '"labels":["TimeoutError","ValidationError"]'
    refute_includes body, '"colors":["var(--color-primary)"]'
    refute_includes body, '"gradientToColors":["var(--color-primary)"]'
    assert_match(/API activity.*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/API activity \(column\).*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/API status split \(donut\).*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/API status spread \(radar\).*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/API success rate \(gauge\).*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/Recent failures.*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/Active users.*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/Job throughput.*?data-controller="flat-pack--chart"/m, response.body)
    assert_operator response.body.scan("grid-cols-1 md:grid-cols-2 lg:grid-cols-3").size, :>=, 2
    assert_operator response.body.scan("gap-4").size, :>=, 2
    assert_operator response.body.scan("my-4").size, :>=, 2
    refute_includes response.body, "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-2 items-stretch my-4"
    refute_includes response.body, "--button-primary-background-color"
    refute_includes response.body, "flex flex-wrap gap-2 my-4"
    refute_includes response.body, "grid gap-4 md:grid-cols-2 xl:grid-cols-4"
    assert_equal admin_root_recording, admin_section_recording.root_recording
    assert_equal admin_root_recording, admin_section_recording.parent_recording
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_async_enabled
  end

  test "admin section widgets load progressively through engine widget endpoints by default" do
    sign_in_admin_user

    get "/admin/sections/root", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, 'data-controller="recording-studio-admin--async-widgets"'
    assert_includes response.body, 'data-recording-studio-admin--async-widgets-max-concurrent-value="4"'
    assert_includes response.body, 'id="recording-studio-admin-widget-section-'
    assert_includes response.body, 'loading="lazy"'
    assert_includes response.body, 'src="/admin/sections/root/widgets/widgets.api_requests.api_activity'
    assert_includes response.body, "/admin/sections/root/widgets/widgets.api_requests.api_activity"
    assert_includes response.body, "min-h-28 max-h-28"
    assert_includes response.body, "min-h-[22rem]"
    assert_includes response.body, "min-h-[15rem]"
    refute_includes response.body, 'data-flat-pack--chart-series-value="[{&quot;name&quot;:&quot;API activity&quot;'

    get "/admin/sections/root/widgets/widgets.api_requests.api_activity", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, 'id="recording-studio-admin-widget-section-'
    assert_includes response.body, "API activity"
    assert_includes response.body, 'data-controller="flat-pack--chart"'
    body = CGI.unescapeHTML(response.body)
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"API activity"'
  end

  test "widget info tooltips render accessible triggers for card and compact variants" do
    sign_in_admin_user
    original_async_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled
    RecordingStudioAdmin.configuration.async_widgets.enabled = false

    get "/admin/sections/root", params: { anchor_url: root_url }

    assert_response :success
    info_tooltips = css_select('[data-controller="flat-pack--tooltip"]').select do |element|
      element.at_css('[role="tooltip"]')&.text == "Counts all API requests received during the selected reporting period."
    end
    assert_equal 2, info_tooltips.size
    info_tooltips.each do |tooltip|
      assert tooltip.at_css('[data-flat-pack--icon-name-value="information-circle"]')
      assert_equal "More information about API activity", tooltip.at_css("button")["aria-label"]
    end

    compact_tooltip = info_tooltips.find { |tooltip| tooltip.ancestors.any? { |ancestor| ancestor["class"].to_s.include?("min-h-28") } }
    assert compact_tooltip, "expected a compact widget info tooltip"
    refute compact_tooltip.ancestors.any? { |ancestor| ancestor.name == "a" }
    refute compact_tooltip.ancestors.any? { |ancestor|
      ancestor["data-controller"].to_s.split.include?("flat-pack--tooltip")
    }

    recent_failures_heading = css_select("h3").find { |heading| heading.text.strip == "Recent failures" }
    recent_failures_card = recent_failures_heading.ancestors.find do |ancestor|
      ancestor["class"].to_s.include?("min-h-28")
    end
    refute recent_failures_card.at_css('[data-flat-pack--icon-name-value="information-circle"]')
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_async_enabled
  end

  test "admin sections index lists sections available to the current user" do
    sign_in_admin_user

    get "/admin/sections", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Admin sections"
    assert_includes response.body, "Admin section"
    assert_includes response.body, "Monitor API traffic, users, jobs, and failures"
    assert_includes response.body, 'data-flat-pack--icon-name-value="folder"'
    assert_includes response.body, "Users"
    assert_includes response.body, "Manage users and review access activity"
    assert_includes response.body, 'data-flat-pack--icon-name-value="user-group"'
    assert_includes response.body, "Admin activity logs"
    assert_includes response.body, "Audit admin CRUD changes and resource actions"
    assert_includes response.body, 'href="/admin/sections/admin_activity_logs?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, 'href="/admin/sections/root?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/sections/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
    assert_includes response.body, "max-w-6xl"
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"
  end

  test "admin activity logs section and screen render audit events chronologically" do
    sign_in_admin_user
    original_async_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled
    RecordingStudioAdmin.configuration.async_widgets.enabled = false

    AdminAuditLog.delete_all
    AdminAuditLog.create!(
      event_id: "event-older",
      resource_key: "users",
      action_key: "update",
      outcome: "performed",
      actor_type: "User",
      actor_id: "1",
      record_type: "User",
      record_id: "24",
      request_id: "req-older",
      occurred_at: 2.hours.ago,
      metadata: { changes: { "email" => [ "before@example.com", "after@example.com" ] } }
    )
    AdminAuditLog.create!(
      event_id: "event-newer",
      resource_key: "pages",
      action_key: "destroy",
      outcome: "failed",
      actor_type: "User",
      actor_id: "2",
      record_type: "Page",
      record_id: "88",
      request_id: "req-newer",
      error_message: "Cannot destroy published page",
      occurred_at: 30.minutes.ago,
      metadata: {}
    )

    get "/admin/sections/admin_activity_logs", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Admin activity logs"
    assert_includes response.body, "View admin activity logs"
    assert_includes response.body, "Admin activity overview"
    assert_includes response.body, 'href="/admin/screens/admin_activity_logs?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    body = CGI.unescapeHTML(response.body)
    assert_includes body, 'data-flat-pack--chart-type-value="area"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Admin events"'

    get "/admin/screens/admin_activity_logs", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, 'id="screen-chart" src="/admin/screens/admin_activity_logs/chart?anchor_url='
    assert_includes response.body, 'id="screen-table" src="/admin/screens/admin_activity_logs/table?anchor_url='

    get "/admin/screens/admin_activity_logs/chart", params: { anchor_url: root_url }

    assert_response :success

    assert_includes response.body, "Activity over time"
    refute_includes response.body, 'id="screen-table"'
    body = CGI.unescapeHTML(response.body)
    assert_includes body, 'data-flat-pack--chart-type-value="area"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Admin events"'

    get "/admin/screens/admin_activity_logs/table", params: { anchor_url: root_url }

    assert_response :success
    table_headers = css_select("th").map { |header| header.text.squish.sub(/\s+[↑↓]\z/, "") }

    assert_includes response.body, "User #2"
    assert_includes response.body, "Page #88"
    assert_includes response.body, "pages.destroy"
    assert_includes response.body, "users.update"
    assert_includes response.body, "Cannot destroy published page"
    refute_includes response.body, "Admin activity overview"
    assert_operator response.body.index("pages.destroy"), :<, response.body.index("users.update")
    assert_equal "Occurred at", table_headers[0]
    assert_equal "Actor", table_headers[1]
    assert_equal "Action", table_headers[2]
    assert_equal "Record", table_headers[3]
    assert_equal "Error", table_headers[4]
    assert_equal "Outcome", table_headers[5]
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_async_enabled
  end

  test "admin sections index renders built-in search results across sections and screens" do
    sign_in_admin_user

    get "/admin/sections", params: { anchor_url: root_url, q: "user" }

    assert_response :success
    assert_includes response.body, 'id="admin-sections-discovery"'
    assert_includes response.body, 'data-controller="flat-pack--auto-submit"'
    assert_includes response.body, 'data-turbo-frame="admin-sections-discovery"'
    assert_includes response.body, "flat-pack--auto-submit#queueSubmit"
    assert_includes response.body, "Search screens and sections"
    assert_includes response.body, 'type="search"'
    assert_includes response.body, 'value="user"'
    assert_includes response.body, 'name="anchor_url"'
    assert_includes response.body, "Users"
    assert_includes response.body, "User activity"
    assert_includes response.body, "User geography"
    assert_includes response.body, "View users"
    assert_includes response.body, "User reviews"
    assert_includes response.body, "User invitations"
    assert_includes response.body, ">Screen<"
    assert_includes response.body, ">Section<"
    assert_includes response.body, 'href="/admin/sections/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_activity?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_geography?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_reviews?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_invitations?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/sections?anchor_url=http%3A%2F%2Fwww.example.com%2F&amp;q=user"'
    assert_includes response.body, 'href="/admin/sections?anchor_url=http%3A%2F%2Fwww.example.com%2F&amp;q=user&amp;type=sections"'
    assert_includes response.body, 'href="/admin/sections?anchor_url=http%3A%2F%2Fwww.example.com%2F&amp;q=user&amp;type=screens"'
    assert_includes response.body, 'data-turbo-frame="admin-sections-discovery"'
    assert_includes response.body, "Sections"
    assert_includes response.body, "In Users"
  end

  test "admin sections index can filter search results to sections or screens only" do
    sign_in_admin_user

    get "/admin/sections", params: { anchor_url: root_url, q: "user", type: "screens" }

    assert_response :success
    assert_includes response.body, 'value="user"'
    assert_includes response.body, 'name="type"'
    assert_includes response.body, 'value="screens"'
    assert_includes response.body, "In Users"
    assert_includes response.body, "User sign-ins"
    assert_includes response.body, "User reviews"
    assert_includes response.body, "User invitations"
    assert_includes response.body, ">Screen<"
    refute_includes response.body, ">Section<"
  end

  test "generated admin root view lists available root sections" do
    sign_in_admin_user

    get "/admin/root", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Admin"
    assert_includes response.body, "flat-pack-page-nav"
    assert_equal 1, response.body.scan("flat-pack-page-nav").count
    assert_includes response.body, "avatar-group"
    assert_includes response.body, "Admin Section Rendering"
    assert_includes response.body, 'aria-label="Go back"'
    assert_includes response.body, 'aria-label="Close"'
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, "Manage and monitor your application"
    assert_includes response.body, "Admin section"
    assert_includes response.body, "Monitor API traffic, users, jobs, and failures"
    assert_includes response.body, 'data-flat-pack--icon-name-value="folder"'
    assert_includes response.body, "Users"
    assert_includes response.body, "Manage users and review access activity"
    assert_includes response.body, 'data-flat-pack--icon-name-value="user-group"'
    assert_includes response.body, 'href="/admin/sections/root?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/sections/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    refute_includes response.body, "Open admin screens"
  end

  test "generated admin root view renders a separate search across admin screens and sections" do
    sign_in_admin_user

    get "/admin/root", params: { anchor_url: root_url, q: "user" }

    assert_response :success
    assert_includes response.body, 'data-controller="admin--root-search"'
    assert_includes response.body, 'type="search"'
    assert_includes response.body, 'value="user"'
    assert_includes response.body, 'name="anchor_url"'
    assert_includes response.body, "Search"
    assert_includes response.body, 'data-action="input->admin--root-search#filter search->admin--root-search#filter"'
    assert_includes response.body, 'data-admin--root-search-target="results"'
    assert_includes response.body, 'data-admin--root-search-target="item"'
    assert_includes response.body, "Users"
    assert_includes response.body, "User sign-ins"
    assert_includes response.body, "User reviews"
    assert_includes response.body, "User invitations"
    assert_includes response.body, ">Screen<"
    assert_includes response.body, ">Section<"
    assert_includes response.body, 'href="/admin/sections/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_sign_ins?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_reviews?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_invitations?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/sections/root?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
  end

  test "generated admin root search renders inside a turbo frame" do
    sign_in_admin_user

    get "/admin/root", params: { anchor_url: root_url, q: "user" }, headers: {
      "Turbo-Frame" => "admin-root-search-results"
    }

    assert_response :success
    assert_includes response.body, '<turbo-frame id="admin-root-search-results"'
    assert_includes response.body, "User sign-ins"
    assert_includes response.body, "User reviews"
    assert_includes response.body, ">Screen<"
    refute_includes response.body, "Manage and monitor your application"
    refute_includes response.body, "No admin sections are available."
  end

  test "users section renders user-specific widgets and screens" do
    sign_in_admin_user
    original_async_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled
    RecordingStudioAdmin.configuration.async_widgets.enabled = false
    UserActivity.delete_all

    UserActivity.create!(email: "member-1@example.com", action: "signed_in", status: "success", created_at: 1.minute.ago, updated_at: 1.minute.ago)
    UserActivity.create!(email: "member-2@example.com", action: "signed_in", status: "review", created_at: 2.minutes.ago, updated_at: 2.minutes.ago)
    UserActivity.create!(email: "member-3@example.com", action: "invited_user", status: "success", created_at: 3.minutes.ago, updated_at: 3.minutes.ago)
    UserActivity.create!(email: "member-4@example.com", action: "exported_report", status: "review", created_at: 4.minutes.ago, updated_at: 4.minutes.ago)

    get "/admin/sections/users", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Users"
    assert_includes response.body, %(/admin/access/recordings/#{admin_root_recording_for_test.id}/accesses)
    refute_includes response.body, ">+ Access<"
    assert_includes response.body, "View users"
    assert_includes response.body, "View user activity"
    assert_includes response.body, "View user sign-ins"
    assert_includes response.body, "View review queue"
    assert_includes response.body, "View invitations"
    assert_includes response.body, ">More<"
    assert_includes response.body, 'href="/admin/screens/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_activity?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_sign_ins?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_reviews?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_invitations?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
    assert_includes response.body, "max-w-6xl"
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"
    assert_includes response.body, "Active users"
    assert_includes response.body, "Sign-in activity"
    assert_includes response.body, "Review queue"
    assert_includes response.body, "User activity (compact column)"
    assert_includes response.body, "User activity (column)"
    assert_includes response.body, "User error distribution (compact pie)"
    assert_includes response.body, "User error distribution (pie)"
    assert_includes response.body, "User status split (compact donut)"
    assert_includes response.body, "User status split (donut)"
    assert_includes response.body, "Total items (compact number)"
    assert_includes response.body, "Review completion"
    assert_includes response.body, "Most recent users"
    refute_includes response.body, "Recent invites"
    assert_includes response.body, "User activity geography"
    assert_operator response.body.scan("User activity geography").count, :>=, 2
    assert_includes response.body, "2 / 4 reviewed"
    assert_includes response.body, 'role="progressbar"'
    assert_includes response.body, 'data-flat-pack--chart-type-value="geochart"'
    assert_includes response.body, "member-3@example.com"
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_async_enabled
  end

  test "users section async widget frames disambiguate compact and full geography widgets" do
    sign_in_admin_user
    original_async_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled
    RecordingStudioAdmin.configuration.async_widgets.enabled = true

    get "/admin/sections/users", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "widget_view_variant=compact"
    assert_includes response.body, "widget_view_variant=__default__"
    assert_operator response.body.scan("/admin/sections/users/widgets/widgets.user_geography.activity_geo_map").count, :>=, 2
    assert_includes response.body, 'target="_top"'

    get "/admin/sections/users/widgets/widgets.user_activity.active_users", params: {
      anchor_url: root_url,
      widget_view_variant: :compact
    }

    assert_response :success
    assert_includes response.body, 'target="_top"'
    assert_includes response.body, 'href="/admin/screens/user_activity?anchor_url='

    UserActivity.delete_all
    UserActivity.create!(email: "compact-user-1@example.com", action: "signed_in", status: "success", created_at: 1.minute.ago, updated_at: 1.minute.ago)
    UserActivity.create!(email: "compact-user-2@example.com", action: "exported_report", status: "review", created_at: 2.minutes.ago, updated_at: 2.minutes.ago)
    UserActivity.create!(email: "compact-user-3@example.com", action: "invited_user", status: "success", created_at: 3.minutes.ago, updated_at: 3.minutes.ago)

    get "/admin/sections/users/widgets/widgets.user_activity.most_recent_users", params: {
      anchor_url: root_url,
      widget_view_variant: :compact
    }

    assert_response :success
    assert_includes response.body, "min-h-28 max-h-28"
    assert_includes response.body, ">3<"
    assert_includes response.body, "flex -space-x-2"
    assert_includes response.body, 'data-flat-pack--icon-name-value="user-circle"'
    refute_includes response.body, "compact-user-1@example.com, compact-user-2@example.com"

    get "/admin/sections/users/widgets/widgets.api_requests.api_activity_column", params: {
      anchor_url: root_url,
      widget_view_variant: :compact
    }

    assert_response :success
    assert_includes response.body, ">User activity (compact column)<"
    assert_includes response.body, "[-webkit-line-clamp:2]"
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_async_enabled
  end

  test "user activity screen async compact widgets preserve the compact frame variant" do
    sign_in_admin_user
    original_async_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled
    RecordingStudioAdmin.configuration.async_widgets.enabled = true

    get "/admin/screens/user_activity", params: {
      anchor_url: root_url,
      date_range_preset: :this_week,
      start_date: Date.new(2026, 6, 15),
      end_date: Date.new(2026, 6, 18)
    }

    assert_response :success
  assert_includes response.body, "widget_view_variant=__default__"
  assert_includes response.body, "widget_render_variant=compact"

    get "/admin/screens/user_activity/widgets/widgets.user_activity.total_activities", params: {
      anchor_url: root_url,
      date_range_preset: :this_week,
      start_date: Date.new(2026, 6, 15),
      end_date: Date.new(2026, 6, 18),
      widget_view_variant: "__default__",
      widget_render_variant: :compact
    }

    assert_response :success
    assert_includes response.body, 'id="recording-studio-admin-widget-screen-'
    assert_includes response.body, 'target="_top"'
    assert_includes response.body, ">Total activities<"
    assert_includes response.body, 'href="/admin/screens/user_activity?anchor_url='
    refute_includes response.body, "More"
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_async_enabled
  end

  test "users screen loads chart widgets and table through async regions" do
    sign_in_admin_user
    original_async_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled
    RecordingStudioAdmin.configuration.async_widgets.enabled = true

    get "/admin/screens/users", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Users"
    assert_includes response.body, "Manage user accounts"
    assert_includes response.body, 'id="screen-filters-mobile-form"'
    assert_includes response.body, 'name="date_range_preset"'
    assert_includes response.body, 'name="group_by"'
    assert_includes response.body, 'value="day"'
    assert_includes response.body, 'name="search"'
    assert_includes response.body, "widget_view_variant=__default__"
    assert_includes response.body, "widget_render_variant=compact"
    assert_includes response.body, "/admin/screens/users/widgets/widgets.users.active_users"
    assert_includes response.body, "/admin/screens/users/widgets/widgets.users.review_completion"
    assert_includes response.body, "/admin/screens/users/widgets/widgets.users.most_recent_users"
    assert_includes response.body, 'id="screen-chart" src="/admin/screens/users/chart?anchor_url='
    assert_includes response.body, 'id="screen-table" src="/admin/screens/users/table?anchor_url='
    assert_includes response.body, "Table data"
    assert_includes response.body, 'id="screen-table-count"'
    assert_includes response.body, 'data-recording-studio-admin-table-cell-skeleton="true"'
    table_headers = css_select("#screen-table th").map { |header| header.text.squish }
    assert_includes table_headers, "Email"
    assert_includes table_headers, "Created at"
    assert_equal 4, css_select("#screen-table tbody tr").size
    assert_includes response.body, "submit-&gt;recording-studio-admin--screen-filters#refreshResultFrames"

    get "/admin/screens/users/chart", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Activity over time"
    assert_includes response.body, 'data-controller="flat-pack--chart"'
    refute_includes response.body, 'id="screen-table"'

    get "/admin/screens/users/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Table data"
    assert_includes response.body, "Columns"
    assert_includes response.body, 'id="screen-table-count" src="/admin/screens/users/table_count?anchor_url='
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_async_enabled
  end

  test "mounted access page renders for the admin root recording" do
    sign_in_admin_user

    get "/admin/access/recordings/#{admin_root_recording_for_test.id}/accesses", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Manage access"
    assert_includes response.body, "admin-section-rendering@example.com"
  end

  test "signed in user without admin root access cannot render admin root section" do
    sign_in_user_without_admin_access

    assert_no_difference -> { AdminSection.count } do
      assert_no_difference -> { RecordingStudio::Recording.count } do
        get "/admin"
      end
    end

    assert_response :forbidden
    refute_includes response.body, "Admin section"
  end

  test "signed in user without admin root access cannot render admin screens" do
    sign_in_user_without_admin_access
    ApiRequest.create!(path: "/hidden", method: "GET", status: 200, latency_ms: 1)

    get "/admin/screens/api_requests"

    assert_response :forbidden
    refute_includes response.body, "/hidden"
  end

  test "admin screen keeps nominated filters inline and preserves modal filter values" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: {
      anchor_url: root_url,
      group_by: :week,
      status: "500"
    }

    assert_response :success
    assert_select "#screen-inline-filters-form label", text: "Date range"
    assert_select "#screen-inline-filters-form label", text: "Group by"
    assert_select "#screen-inline-filters-form label", text: "Status", count: 0
    assert_select "#screen-inline-filters-form label", text: "Search", count: 0
    assert_select "#screen-inline-filters-form input[type='hidden'][name='status'][value='500']"
    assert_select "#screen-filters-mobile-form label", text: "Status"
    assert_select "#screen-filters-mobile-form label", text: "Search"
    assert_select "#screen-filters-mobile-form label", text: "Date range", count: 0
    assert_select "#screen-filters-mobile-form label", text: "Group by", count: 0
    assert_select "#screen-filters-mobile-form input[type='hidden'][name='group_by'][value='week']"
    assert_includes response.body, "!w-auto"
  end

  test "admin screen renders streamlined filters with table results" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "API requests"
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, 'name="anchor_url"'
    assert_includes response.body, 'value="http://www.example.com/"'
    assert_includes response.body, "recording-studio-admin--screen-filters"
    assert_includes response.body, 'data-turbo-frame="screen-filters"'
    assert_includes response.body, "change-&gt;recording-studio-admin--screen-filters#showTableSkeletons"
    assert_includes response.body, "submit-&gt;recording-studio-admin--screen-filters#showTableSkeletons"
    assert_includes response.body, "click->recording-studio-admin--screen-filters#queueDateRangeSubmit"
    assert_includes response.body, 'id="screen-chart" src="/admin/screens/api_requests/chart?anchor_url='
    assert_includes response.body, 'id="screen-filters-mobile-form"'
    assert_includes response.body, 'name="search"'
    assert_includes response.body, 'data-modal-id="screen-filters-modal"'
    assert_includes response.body, 'id="screen-filters-modal"'
    assert_includes response.body, "Filters"
    assert_includes response.body, "Apply"
    assert_includes response.body, "data-recording-studio-admin--screen-filters-modal-filters-value"
    assert_includes response.body, 'name="status"'
    assert_select "#screen-inline-filters-form label", text: "Date range"
    assert_select "#screen-inline-filters-form label", text: "Group by"
    assert_select "#screen-filters label", text: "Status"
    assert_select "#screen-filters label", text: "Search"
    assert_includes response.body, "Monthly API usage"
    assert_includes response.body, "/admin/screens/api_requests/widgets/widgets.api_requests.monthly_api_usage"
    assert_includes response.body, 'id="screen-table" src="/admin/screens/api_requests/table?anchor_url='
    refute_includes response.body, "/ 10000 requests"
    refute_includes response.body, 'role="progressbar"'

    get "/admin/screens/api_requests/chart", params: { anchor_url: root_url }

    assert_response :success
    refute_includes response.body, 'id="screen-table"'
    assert_includes response.body, 'data-controller="flat-pack--chart"'
    chart_title = css_select("h3").find { |heading| heading.text.strip == "Requests over time" }
    assert chart_title, "expected Requests over time heading"
    chart_count = chart_title.ancestors.find { |node| node["class"].to_s.include?("mb-4") }&.css("p.text-5xl")&.first
    assert chart_count, "expected a large chart count under the chart title"
    assert_match(/\A\d+\z/, chart_count.text.strip)

    get "/admin/screens/api_requests/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Table data"
    assert_includes response.body, "Columns"
    assert_includes response.body, 'id="screen-table-count" src="/admin/screens/api_requests/table_count?anchor_url='
    assert_includes response.body, "sort=created_at"
    assert_includes response.body, 'data-turbo-frame="screen-table"'
    assert_includes response.body, 'data-action="click-&gt;recording-studio-admin--screen-filters#showTableSkeletons"'
    assert_includes response.body, 'data-pagination-content="true"'
    assert_includes response.body, 'action="/recording_studio_exportable/exports"'
    assert_includes response.body, 'name="export_token"'
    assert_includes response.body, 'name="format"'
    assert_includes response.body, 'value="csv"'
    refute_includes response.body, 'name="export_key"'
    assert_includes response.body, 'data-turbo="false"'
    assert_includes response.body, "Export"
    assert_includes response.body, "Columns"
    assert_includes response.body, 'data-modal-id="screen-table-columns-modal"'
    assert_includes response.body, 'id="screen-table-columns-modal"'
    assert_includes response.body, "Choose table columns"
    assert_includes response.body, 'name="columns[]"'
    assert_includes response.body, 'id="screen-table-columns-form"'

    table_headers = css_select("th").map { |header| header.text.squish.sub(/\s+[↑↓]\z/, "") }

    assert_includes table_headers, "Created at"
    assert_includes table_headers, "Method"
    assert_includes table_headers, "Status"
    assert_includes table_headers, "Path"
    refute_includes table_headers, "Latency"

    # Depending on seeded records, the table may render row badges/timestamps or empty state text.
    has_row_metadata = response.body.include?("bg-[var(--badge-success-background-color)]") &&
      response.body.include?('data-controller="flat-pack--timestamp"')
    has_empty_state = response.body.include?("No data available")
    assert(has_row_metadata || has_empty_state, "expected either row metadata or empty-state table output")

    if response.body.include?('data-controller="flat-pack--pagination-infinite"')
      assert_includes response.body, 'data-flat-pack--pagination-infinite-url-value="/admin/screens/api_requests/table?anchor_url='
      assert_includes response.body, '&amp;page=2"'
    end

    refute_includes response.body, "Apply filters"
    refute_includes response.body, "flex items-start justify-between gap-4 p-6"
    refute_includes response.body, "Filters"
    refute_includes response.body, "Group By"
    refute_includes response.body, "grid-cols-1 md:grid-cols-2 lg:grid-cols-4"
    refute_includes response.body, "screen-results"
    refute_includes response.body, "my-4"

    get "/admin/screens/api_requests/widgets/widgets.api_requests.monthly_api_usage", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Monthly API usage"
    assert_includes response.body, "/ 10000 requests"
    assert_includes response.body, 'role="progressbar"'
  end

  test "admin screen modal filters use FlatPack's active-count badge" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: { anchor_url: root_url, search: "requests" }

    assert_response :success
    assert_includes response.body, 'id="screen-filters"'
    assert_includes response.body, 'id="screen-filters-modal"'
    assert_includes response.body, 'id="screen-filters-mobile-form"'
    assert_includes response.body, 'data-turbo-frame="screen-filters"'
    assert_includes response.body, "px-[var(--button-padding-x-lg)]"
    assert_select "#screen-filters button[data-modal-id='screen-filters-modal'] span.rounded-full", text: "1"

    get "/admin/screens/api_requests", params: { anchor_url: root_url, search: "requests" }, headers: { "Turbo-Frame" => "screen-filters" }

    assert_response :success
    assert_includes response.body, '<turbo-frame id="screen-filters">'
    assert_includes response.body, "px-[var(--button-padding-x-lg)]"
    assert_select "#screen-filters button[data-modal-id='screen-filters-modal'] span.rounded-full", text: "1"
  end

  test "admin screen column picker shows selected columns and falls back to defaults" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: {
      columns: %w[created_at latency_ms],
      columns_present: "1"
    }, headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, 'id="screen-table"'

    selected_headers = css_select("th").map { |header| header.text.squish.sub(/\s+[↑↓]\z/, "") }

    assert_includes selected_headers, "Created at"
    assert selected_headers.any? { |header| header.start_with?("Latency") }
    refute_includes selected_headers, "Method"
    refute_includes selected_headers, "Status"
    refute_includes selected_headers, "Path"
    assert_includes response.body, "Reset"
    assert_includes response.body, 'name="columns_present"'
    assert_includes response.body, "flat-pack--tooltip"
    refute_includes response.body, 'title="0ms total request time"'
    assert_includes response.body, "Total request time in milliseconds"

    get "/admin/screens/api_requests", params: {
      columns_present: "1"
    }, headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, 'id="screen-table"'

    fallback_headers = css_select("th").map { |header| header.text.squish.sub(/\s+[↑↓]\z/, "") }

    assert_includes fallback_headers, "Created at"
    assert_includes fallback_headers, "Method"
    assert_includes fallback_headers, "Status"
    assert_includes fallback_headers, "Path"
    refute_includes fallback_headers, "Latency"
  end

  test "admin screen export includes all filtered rows instead of the paginated table page" do
    sign_in_admin_user
    ApiRequest.delete_all

    30.times do |index|
      ApiRequest.create!(
        path: "/v1/export-all/#{index}",
        method: "GET",
        status: 200,
        latency_ms: index,
        created_at: index.minutes.ago,
        updated_at: index.minutes.ago
      )
    end

    post "/recording_studio_exportable/exports", params: {
      context_recording_id: admin_root_recording_for_test.id,
      export_key: "admin.api_requests",
      format: "csv",
      attributes: {
        screen_key: "api_requests",
        columns: [ "path" ]
      },
      filters: {
        search: "export-all"
      }
    }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_equal 31, response.body.lines.size
    assert_includes response.body, "/v1/export-all/0"
    assert_includes response.body, "/v1/export-all/29"
  end

  test "admin screen renders a tooltip-wrapped table cell value" do
    sign_in_admin_user
    ApiRequest.delete_all
    ApiRequest.create!(
      path: "/v1/tooltip",
      method: "GET",
      status: 200,
      latency_ms: 123,
      created_at: Time.current,
      updated_at: Time.current
    )

    get "/admin/screens/api_requests/table", params: {
      columns: [ "latency_ms" ],
      columns_present: "1"
    }

    assert_response :success

    latency_tooltip = css_select('[data-controller="flat-pack--tooltip"]').find do |element|
      element.at_css('[role="tooltip"]')&.text == "123ms total request time"
    end

    assert latency_tooltip, "expected a latency tooltip"
    assert_includes latency_tooltip.children.select(&:text?).map(&:text).join, "123"
  end

  test "admin screen trusted export token includes selected columns and all filtered rows" do
    sign_in_admin_user
    ApiRequest.delete_all

    30.times do |index|
      ApiRequest.create!(
        path: "/v1/token-export/#{index}",
        method: "GET",
        status: 200,
        latency_ms: index,
        created_at: index.minutes.ago,
        updated_at: index.minutes.ago
      )
    end

    get "/admin/screens/api_requests/table", params: {
      search: "token-export",
      columns: [ "path" ],
      columns_present: "1"
    }

    assert_response :success
    token_field = css_select('input[name="export_token"]').first
    assert token_field, "expected export token field"

    post "/recording_studio_exportable/exports", params: {
      export_token: token_field["value"],
      format: "csv",
      filters: { search: "token-export" }
    }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_equal 31, response.body.lines.size
    assert_equal "Path", response.body.lines.first.strip
    assert_includes response.body, "/v1/token-export/0"
    assert_includes response.body, "/v1/token-export/29"
  end

  test "admin screen search filter updates chart totals and table rows together" do
    sign_in_admin_user
    ApiRequest.delete_all

    ApiRequest.create!(path: "/v1/alpha", method: "GET", status: 200, latency_ms: 12, created_at: 5.minutes.ago, updated_at: 5.minutes.ago)
    ApiRequest.create!(path: "/v1/beta", method: "GET", status: 200, latency_ms: 14, created_at: 4.minutes.ago, updated_at: 4.minutes.ago)

    get "/admin/screens/api_requests/chart", params: { anchor_url: root_url, search: "alpha" }

    assert_response :success
    chart_title = css_select("h3").find { |heading| heading.text.strip == "Requests over time" }
    assert chart_title, "expected Requests over time heading"

    chart_count = chart_title.ancestors.find { |node| node["class"].to_s.include?("mb-4") }&.css("p.text-5xl")&.first
    assert chart_count, "expected a large chart count under the chart title"
    assert_equal "1", chart_count.text.strip

    get "/admin/screens/api_requests/table", params: { anchor_url: root_url, search: "alpha" }

    assert_response :success
    assert_includes response.body, "/v1/alpha"
    refute_includes response.body, "/v1/beta"
  end

  test "user activity screen uses infinite scroll by default for table pagination" do
    sign_in_admin_user
    UserActivity.delete_all

    60.times do |index|
      UserActivity.create!(
        email: "scroll-user-#{index}@example.com",
        action: "signed_in",
        status: index.even? ? "success" : "review",
        created_at: index.minutes.ago,
        updated_at: index.minutes.ago
      )
    end

    get "/admin/screens/user_activity", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "User activity"
    assert_includes response.body, 'id="screen-chart" src="/admin/screens/user_activity/chart?anchor_url='
    assert_includes response.body, 'id="screen-table" src="/admin/screens/user_activity/table?anchor_url='
    assert_includes response.body, "Table data"
    assert_includes response.body, 'id="screen-table-count"'
    assert_includes response.body, 'data-recording-studio-admin-table-cell-skeleton="true"'
    assert_equal 4, css_select("#screen-table tbody tr").size

    get "/admin/screens/user_activity/chart", params: { anchor_url: root_url }

    assert_response :success
    refute_includes response.body, 'id="screen-table"'
    assert_includes response.body, 'data-controller="flat-pack--chart"'

    get "/admin/screens/user_activity/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Table data"
    assert_includes response.body, "Counting rows..."
    assert_includes response.body, 'id="screen-table-count" src="/admin/screens/user_activity/table_count?anchor_url='
    assert_includes response.body, "Actions"
    assert_includes response.body, "ellipsis-vertical"
    assert_includes response.body, "View sign-ins"
    assert_includes response.body, "Review queue"
    assert_includes response.body, "Delete activity"
    assert_includes response.body, 'data-turbo-method="delete"'
    assert_includes response.body, 'data-turbo-confirm="Delete activity for scroll-user-0@example.com?"'
    assert_includes response.body, "/admin/user_activities/"
    assert_includes response.body, "/admin/screens/user_reviews"
    assert_includes response.body, 'data-pagination-content="true"'
    assert_includes response.body, 'data-controller="flat-pack--pagination-infinite"'
    assert_includes response.body, 'data-flat-pack--pagination-infinite-loading-variant-value="inline"'
    assert_includes response.body, 'data-flat-pack--pagination-infinite-url-value="/admin/screens/user_activity/table?'
    assert_includes response.body, '&amp;page=2"'
    assert_includes response.body, 'data-recording-studio-admin-table-cell-content="true"'
    assert_includes response.body, 'data-recording-studio-admin-table-cell-skeleton="true"'
    refute_includes response.body, 'href="/admin/screens/user_activity?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    refute_includes response.body, ">End<"

    get "/admin/screens/user_activity/table", params: { anchor_url: root_url, page: 2 }, headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :success
    assert_includes response.body, 'id="screen-table"'
    assert_includes response.body, "Table data"
    assert_includes response.body, 'data-controller="flat-pack--pagination-infinite"'
    assert_includes response.body, 'data-flat-pack--pagination-infinite-loading-variant-value="inline"'
    assert_includes response.body, '&amp;page=3"'
    refute_includes response.body, 'data-controller="flat-pack--chart"'
    refute_includes response.body, "Activity over time"
    refute_includes response.body, 'id="screen-filters-form"'

    get "/admin/screens/user_activity/table", params: { anchor_url: root_url, page: 3 }, headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :success
    assert_includes response.body, 'id="screen-table"'
    assert_includes response.body, ">End<"
    refute_includes response.body, 'data-controller="flat-pack--pagination-infinite"'

    get "/admin/screens/user_activity/table_count", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, 'id="screen-table-count"'
    assert_includes response.body, "60 rows"
  end

  test "user-specific screens render filtered activity views" do
    sign_in_admin_user
    UserActivity.delete_all

    UserActivity.create!(email: "signin-only@example.com", action: "signed_in", status: "success", created_at: 5.minutes.ago, updated_at: 5.minutes.ago)
    UserActivity.create!(email: "review-only@example.com", action: "exported_report", status: "review", created_at: 4.minutes.ago, updated_at: 4.minutes.ago)
    UserActivity.create!(email: "invite-only@example.com", action: "invited_user", status: "success", created_at: 3.minutes.ago, updated_at: 3.minutes.ago)

    get "/admin/screens/user_sign_ins", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "User sign-ins"

    get "/admin/screens/user_sign_ins/chart", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Sign-ins over time"

    get "/admin/screens/user_sign_ins/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "signin-only@example.com"
    assert_includes response.body, "Actions"
    assert_includes response.body, "View activity"
    assert_includes response.body, "Delete sign-in"
    assert_includes response.body, 'data-turbo-confirm="Delete sign-in activity for signin-only@example.com?"'
    refute_includes response.body, "review-only@example.com"

    get "/admin/screens/user_reviews", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "User reviews"

    get "/admin/screens/user_reviews/chart", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Review activity"

    get "/admin/screens/user_reviews/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "review-only@example.com"
    assert_includes response.body, "View sign-ins"
    assert_includes response.body, "Delete review"
    assert_includes response.body, 'data-turbo-confirm="Delete review activity for review-only@example.com?"'
    refute_includes response.body, "invite-only@example.com"

    get "/admin/screens/user_invitations", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "User invitations"

    get "/admin/screens/user_invitations/chart", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Invitations over time"

    get "/admin/screens/user_invitations/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "invite-only@example.com"
    assert_includes response.body, "View sign-ins"
    assert_includes response.body, "Delete invitation"
    assert_includes response.body, 'data-turbo-confirm="Delete invitation activity for invite-only@example.com?"'
    refute_includes response.body, "signin-only@example.com"
  end

  test "example admin screens render row action menus" do
    sign_in_admin_user
    ApiRequest.delete_all
    ApiError.delete_all
    BackgroundJobRun.delete_all

    ApiRequest.create!(path: "/v1/fail", method: "POST", status: 500, latency_ms: 42, created_at: 5.minutes.ago, updated_at: 5.minutes.ago)
    ApiError.create!(error_class: "TimeoutError", message: "request timed out", path: "/v1/fail", status: 504, created_at: 4.minutes.ago, updated_at: 4.minutes.ago)
    BackgroundJobRun.create!(job_class: "ProcessWebhookJob", queue: "critical", status: "failed", duration_ms: 120, created_at: 3.minutes.ago, updated_at: 3.minutes.ago)

    get "/admin/screens/api_requests/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Filter path"
    assert_includes response.body, "View errors"
    assert_includes response.body, "search=%2Fv1%2Ffail"

    get "/admin/screens/api_errors/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "View requests"
    assert_includes response.body, "Similar errors"
    assert_includes response.body, "search=TimeoutError"

    get "/admin/screens/background_jobs/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "View job class"
    assert_includes response.body, "Filter queue"
    assert_includes response.body, "queue=critical"
  end

  test "admin screen chart turbo frame reloads with filtered data" do
    sign_in_admin_user
    ApiError.delete_all
    ApiError.create!(
      error_class: "TimeoutError",
      message: "request timed out",
      path: "/v1/timeout",
      status: 504,
      created_at: 5.minutes.ago,
      updated_at: 5.minutes.ago
    )

    get "/admin/screens/api_errors", headers: { "Turbo-Frame" => "screen-chart" }

    assert_response :success
    body = CGI.unescapeHTML(response.body)
    assert_includes response.body, 'id="screen-chart"'

    assert_includes body, "+100%"
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Errors"'
    has_chart_points = body.include?('"x":"')
    has_empty_series = body.include?('data-flat-pack--chart-series-value="[{"name":"Errors","data":[]}]"')
    assert(has_chart_points || has_empty_series, "expected either populated chart buckets or an empty chart series")

    get "/admin/screens/api_errors", params: {
      start_date: 100.years.ago.to_date.iso8601,
      end_date: 90.years.ago.to_date.iso8601
    }, headers: { "Turbo-Frame" => "screen-chart" }

    assert_response :success
    body = CGI.unescapeHTML(response.body)
    assert_includes body, 'id="screen-chart"'

    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Errors","data":[]}]"'
  end

  test "admin screen table turbo frame reloads without rerendering the chart" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: {
      anchor_url: root_url,
      sort: "created_at",
      direction: "asc"
    }, headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, 'id="screen-table"'
    assert_includes response.body, "Table data"
    assert_includes response.body, 'data-turbo-frame="screen-table"'
    assert_includes response.body, "Created at ↑"
    refute_includes response.body, 'data-controller="flat-pack--chart"'
    refute_includes response.body, "Requests over time"
  end

  test "most common errors screen renders a pie chart and table data" do
    sign_in_admin_user
    ApiError.delete_all

    ApiError.create!(error_class: "TimeoutError", message: "request timed out", path: "/v1/timeout", status: 504, created_at: 5.minutes.ago, updated_at: 5.minutes.ago)
    ApiError.create!(error_class: "TimeoutError", message: "worker timeout", path: "/v1/worker", status: 504, created_at: 4.minutes.ago, updated_at: 4.minutes.ago)
    ApiError.create!(error_class: "ValidationError", message: "invalid body", path: "/v1/orders", status: 422, created_at: 3.minutes.ago, updated_at: 3.minutes.ago)

    get "/admin/screens/most_common_errors", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Most common errors"

    get "/admin/screens/most_common_errors/chart", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Top error classes"

    body = CGI.unescapeHTML(response.body)
    assert_includes body, 'data-flat-pack--chart-type-value="pie"'
    assert_includes body, 'data-flat-pack--chart-series-value="[2,1]"'
    assert_includes body, '"labels":["TimeoutError","ValidationError"]'

    get "/admin/screens/most_common_errors/table", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Error breakdown"
    refute_includes response.body, "Table data"
    refute_includes response.body, "Columns"
    refute_includes response.body, "Table columns"
    refute_includes response.body, 'id="screen-table-columns-modal"'
    refute_includes response.body, "Counting rows..."
    refute_includes response.body, 'id="screen-table-count"'
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
