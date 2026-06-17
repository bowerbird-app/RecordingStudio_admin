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

    ApiError.delete_all
    ApiError.create!(error_class: "TimeoutError", message: "timeout", path: "/v1/timeout", status: 504, created_at: 2.minutes.ago, updated_at: 2.minutes.ago)
    ApiError.create!(error_class: "TimeoutError", message: "timeout again", path: "/v1/timeout", status: 504, created_at: 1.minute.ago, updated_at: 1.minute.ago)
    ApiError.create!(error_class: "ValidationError", message: "invalid payload", path: "/v1/payload", status: 422, created_at: 3.minutes.ago, updated_at: 3.minutes.ago)

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
    assert_includes response.body, "View API requests"
    assert_includes response.body, 'href="/admin/screens/api_requests?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, ">More<"
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"
    refute_includes response.body, "max-w-6xl"
    refute_includes response.body, "Admin menu"
    assert_includes response.body, "View most common errors"
    assert_includes response.body, 'href="/admin/screens/most_common_errors?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "View users"
    assert_includes response.body, 'href="/admin/screens/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "View background jobs"
    assert_includes response.body, 'href="/admin/screens/background_jobs?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "API activity"
    assert_includes response.body, "Open API requests"
    assert_includes response.body, "Open Most common errors"
    refute_includes response.body, "Total API requests recorded during the last 24 hours."
    assert_includes response.body, "Recent failures"
    assert_includes response.body, "Most common errors"
    assert_includes response.body, "Active users"
    assert_includes response.body, "Review completion"
    assert_includes response.body, "2 / 3 reviewed"
    assert_includes response.body, 'role="progressbar"'
    refute_includes response.body, "Last 14 days"
    assert_includes response.body, "Most recent users"
    assert_includes response.body, "Latest five users"
    assert_includes response.body, "recent-user-1@example.com"
    assert_includes response.body, "recent-user-2@example.com"
    assert_includes response.body, "recent-user-3@example.com"
    assert_includes response.body, 'data-flat-pack--icon-name-value="user-circle"'
    assert_includes response.body, 'href="/users/recent-user-1-example-com"'
    assert_includes response.body, 'href="/users/recent-user-2-example-com"'
    assert_includes response.body, 'href="/users/recent-user-3-example-com"'
    assert_includes response.body, "hover:bg-[var(--list-item-hover-background-color)]"
    assert_includes response.body, "Job throughput"
    body = CGI.unescapeHTML(response.body)
    assert_operator body.scan("data-flat-pack--chart-series-value=").size, :>=, 4
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"API activity"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Recent failures"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Active users"'
    assert_includes body, 'data-flat-pack--chart-series-value="[{"name":"Job throughput"'
    assert_includes body, 'data-flat-pack--chart-series-value="[2,1]"'
    assert_includes body, 'data-flat-pack--chart-type-value="pie"'
    assert_includes body, '"labels":["TimeoutError","ValidationError"]'
    refute_includes body, '"colors":["var(--color-primary)"]'
    refute_includes body, '"gradientToColors":["var(--color-primary)"]'
    assert_match(/API activity.*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/Recent failures.*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/Active users.*?data-controller="flat-pack--chart"/m, response.body)
    assert_match(/Job throughput.*?data-controller="flat-pack--chart"/m, response.body)
    assert_operator response.body.scan("grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4").size, :>=, 2
    assert_operator response.body.scan("gap-4").size, :>=, 2
    assert_operator response.body.scan("my-4").size, :>=, 2
    refute_includes response.body, "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-2 items-stretch my-4"
    refute_includes response.body, "--button-primary-background-color"
    refute_includes response.body, "flex flex-wrap gap-2 my-4"
    refute_includes response.body, "grid gap-4 md:grid-cols-2 xl:grid-cols-4"
    assert_equal admin_root_recording, admin_section_recording.root_recording
    assert_equal admin_root_recording, admin_section_recording.parent_recording
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
    assert_includes response.body, "Explore user activity, sign-ins, reviews, and invitations"
    assert_includes response.body, 'data-flat-pack--icon-name-value="user-group"'
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, 'href="/admin/sections/root?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/sections/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"
    refute_includes response.body, "max-w-6xl"
  end

  test "generated admin root view lists available root sections" do
    sign_in_admin_user

    get "/admin/root", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Admin"
    assert_includes response.body, "flat-pack-page-nav"
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
    assert_includes response.body, "Explore user activity, sign-ins, reviews, and invitations"
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

  test "users section renders user-specific widgets and screens" do
    sign_in_admin_user
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
    assert_includes response.body, "View users overview"
    assert_includes response.body, "View user sign-ins"
    assert_includes response.body, "View review queue"
    assert_includes response.body, "View invitations"
    assert_includes response.body, ">More<"
    assert_includes response.body, 'href="/admin/screens/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_sign_ins?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_reviews?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, 'href="/admin/screens/user_invitations?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"
    refute_includes response.body, "max-w-6xl"
    assert_includes response.body, "Active users"
    assert_includes response.body, "Sign-in activity"
    assert_includes response.body, "Review queue"
    assert_includes response.body, "Review completion"
    assert_includes response.body, "Most recent users"
    assert_includes response.body, "Recent invites"
    assert_includes response.body, "2 / 4 reviewed"
    assert_includes response.body, 'role="progressbar"'
    assert_includes response.body, "member-3@example.com"
    assert_includes response.body, 'data-flat-pack--icon-name-value="user-plus"'
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

  test "admin screen renders streamlined filters with table results" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    table_headers = css_select("th").map { |header| header.text.squish.sub(/\s+[↑↓]\z/, "") }

    assert_includes response.body, "API requests"
    assert_includes response.body, "Requests over time"
    chart_title = css_select("h3").find { |heading| heading.text.strip == "Requests over time" }
    assert chart_title, "expected Requests over time heading"
    chart_count = chart_title.ancestors.find { |node| node["class"].to_s.include?("mb-4") }&.css("p.text-5xl")&.first
    assert chart_count, "expected a large chart count under the chart title"
    assert_match(/\A\d+\z/, chart_count.text.strip)
    assert_includes response.body, 'href="http://www.example.com/"'
    assert_includes response.body, 'name="anchor_url"'
    assert_includes response.body, 'value="http://www.example.com/"'
    assert_includes response.body, "Table data"
    assert_includes response.body, "sort=created_at"
    assert_includes response.body, "flat-pack--auto-submit"
    assert_includes response.body, "recording-studio-admin--screen-filters"
    assert_includes response.body, 'data-turbo-frame="screen-chart"'
    assert_includes response.body, 'id="screen-table"'
    assert_includes response.body, 'data-turbo-frame="screen-table"'
    assert_includes response.body, "click-&gt;recording-studio-admin--screen-filters#queueDateRangeSubmit"
    assert_includes response.body, 'data-pagination-content="true"'
    assert_includes response.body, 'id="screen-chart"'
    assert_includes response.body, 'id="screen-filters-form"'
    assert_includes response.body, 'name="search"'
    assert_includes response.body, "flex flex-wrap items-start gap-4"
    assert_includes response.body, "min-w-64 flex-none"
    assert_includes response.body, "Columns"
    assert_includes response.body, 'data-modal-id="screen-table-columns-modal"'
    assert_includes response.body, 'id="screen-table-columns-modal"'
    assert_includes response.body, "Choose table columns"
    assert_includes response.body, 'name="columns[]"'
    assert_includes response.body, 'id="screen-table-columns-form"'
    assert_includes response.body, "Monthly API usage"
    assert_includes response.body, "/ 10000 requests"
    assert_includes response.body, 'role="progressbar"'
    assert_includes response.body, "API requests"
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
      assert_includes response.body, 'data-flat-pack--pagination-infinite-url-value="/admin/screens/api_requests?anchor_url=http%3A%2F%2Fwww.example.com%2F&amp;page=2"'
    end

    refute_includes response.body, "Apply filters"
    refute_includes response.body, "flex items-start justify-between gap-4 p-6"
    refute_includes response.body, "Filters"
    refute_includes response.body, "Group By"
    refute_includes response.body, "grid-cols-1 md:grid-cols-2 lg:grid-cols-4"
    refute_includes response.body, "screen-results"
    refute_includes response.body, "my-4"
  end

  test "admin screen column picker shows selected columns and falls back to defaults" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: {
      columns: %w[created_at latency_ms],
      columns_present: "1"
    }, headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success

    selected_headers = css_select("th").map { |header| header.text.squish.sub(/\s+[↑↓]\z/, "") }

    assert_includes selected_headers, "Created at"
    assert_includes selected_headers, "Latency"
    refute_includes selected_headers, "Method"
    refute_includes selected_headers, "Status"
    refute_includes selected_headers, "Path"
    assert_includes response.body, "Reset"
    assert_includes response.body, 'name="columns_present"'

    get "/admin/screens/api_requests", params: {
      columns_present: "1"
    }, headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success

    fallback_headers = css_select("th").map { |header| header.text.squish.sub(/\s+[↑↓]\z/, "") }

    assert_includes fallback_headers, "Created at"
    assert_includes fallback_headers, "Method"
    assert_includes fallback_headers, "Status"
    assert_includes fallback_headers, "Path"
    refute_includes fallback_headers, "Latency"
  end

  test "admin screen search filter updates chart totals and table rows together" do
    sign_in_admin_user
    ApiRequest.delete_all

    ApiRequest.create!(path: "/v1/alpha", method: "GET", status: 200, latency_ms: 12, created_at: 5.minutes.ago, updated_at: 5.minutes.ago)
    ApiRequest.create!(path: "/v1/beta", method: "GET", status: 200, latency_ms: 14, created_at: 4.minutes.ago, updated_at: 4.minutes.ago)

    get "/admin/screens/api_requests", params: { anchor_url: root_url, search: "alpha" }

    assert_response :success
    chart_title = css_select("h3").find { |heading| heading.text.strip == "Requests over time" }
    assert chart_title, "expected Requests over time heading"

    chart_count = chart_title.ancestors.find { |node| node["class"].to_s.include?("mb-4") }&.css("p.text-5xl")&.first
    assert chart_count, "expected a large chart count under the chart title"
    assert_equal "1", chart_count.text.strip
    assert_includes response.body, "/v1/alpha"
    refute_includes response.body, "/v1/beta"
  end

  test "users screen uses infinite scroll by default for table pagination" do
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

    get "/admin/screens/users", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Users"
    assert_includes response.body, "+100%"
    assert_includes response.body, "text-[var(--color-success-background-color)]"
    assert_includes response.body, "Table data"
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
    assert_includes response.body, 'data-flat-pack--pagination-infinite-url-value="/admin/screens/users?'
    assert_includes response.body, '&amp;page=2"'
    refute_includes response.body, 'href="/admin/screens/users?anchor_url=http%3A%2F%2Fwww.example.com%2F"'
    refute_includes response.body, ">End<"

    get "/admin/screens/users", params: { anchor_url: root_url, page: 2 }, headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :success
    assert_includes response.body, "Activity over time"
    assert_includes response.body, 'data-controller="flat-pack--chart"'
    assert_includes response.body, 'data-controller="flat-pack--pagination-infinite"'
    assert_includes response.body, '&amp;page=3"'
    refute_includes response.body, 'id="screen-filters-form"'

    get "/admin/screens/users", params: { anchor_url: root_url, page: 3 }, headers: { "X-Requested-With" => "XMLHttpRequest" }

    assert_response :success
    assert_includes response.body, ">End<"
    refute_includes response.body, 'data-controller="flat-pack--pagination-infinite"'
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
    assert_includes response.body, "Sign-ins over time"
    assert_includes response.body, "signin-only@example.com"
    assert_includes response.body, "Actions"
    assert_includes response.body, "View activity"
    assert_includes response.body, "Delete sign-in"
    assert_includes response.body, 'data-turbo-confirm="Delete sign-in activity for signin-only@example.com?"'
    refute_includes response.body, "review-only@example.com"

    get "/admin/screens/user_reviews", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "User reviews"
    assert_includes response.body, "Review activity"
    assert_includes response.body, "review-only@example.com"
    assert_includes response.body, "View sign-ins"
    assert_includes response.body, "Delete review"
    assert_includes response.body, 'data-turbo-confirm="Delete review activity for review-only@example.com?"'
    refute_includes response.body, "invite-only@example.com"

    get "/admin/screens/user_invitations", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "User invitations"
    assert_includes response.body, "Invitations over time"
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

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Filter path"
    assert_includes response.body, "View errors"
    assert_includes response.body, "search=%2Fv1%2Ffail"

    get "/admin/screens/api_errors", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "View requests"
    assert_includes response.body, "Similar errors"
    assert_includes response.body, "search=TimeoutError"

    get "/admin/screens/background_jobs", params: { anchor_url: root_url }

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
    assert_includes response.body, "Top error classes"
    assert_includes response.body, "Table data"
    assert_includes response.body, "Error class"
    assert_includes response.body, "Count"
    assert_includes response.body, "TimeoutError"
    assert_includes response.body, "ValidationError"
    assert_includes response.body, "View API errors"
    assert_includes response.body, "Filter breakdown"

    body = CGI.unescapeHTML(response.body)
    assert_includes body, 'data-flat-pack--chart-type-value="pie"'
    assert_includes body, 'data-flat-pack--chart-series-value="[2,1]"'
    assert_includes body, '"labels":["TimeoutError","ValidationError"]'
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
