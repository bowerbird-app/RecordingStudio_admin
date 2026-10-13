# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Literal-English render assertions for wave-2 controller/JS copy.
# Strengthens thin key-only locale checks with real page output.
class AdminI18nRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "admin-i18n-render@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    grant_admin_access_for_test!(recording: admin_root_recording_for_test, actor: user)
    sign_in user
  end

  def admin_root_recording_for_test
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end

  test "sections search groups render literal English Sections Screens and In headings" do
    sign_in_admin_user

    get "/admin/sections", params: { anchor_url: root_url, q: "user" }

    assert_response :success
    assert_includes response.body, "<h3"
    assert_includes response.body, "Sections"
    assert_includes response.body, "In Users"
    assert_includes response.body, "Admin sections"
    assert_includes response.body, "Search screens and sections"
    assert_includes response.body, ">Screen<"
    assert_includes response.body, ">Section<"
  end

  test "screen filters pass date preset labels as JSON with English literals" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "data-recording-studio-admin--screen-filters-date-preset-labels-value"
    assert_includes response.body, 'today&quot;:&quot;Today&quot;'
    assert_includes response.body, 'yesterday&quot;:&quot;Yesterday&quot;'
    assert_includes response.body, 'last_3_days&quot;:&quot;Last 3 days&quot;'
    assert_includes response.body, 'this_week&quot;:&quot;This week&quot;'
    assert_includes response.body, 'last_week&quot;:&quot;Last week&quot;'
    assert_includes response.body, 'this_month&quot;:&quot;This month&quot;'
    assert_includes response.body, 'last_month&quot;:&quot;Last month&quot;'
    assert_includes response.body, 'this_year&quot;:&quot;This year&quot;'
    # Boot-order host override covers last_year; other presets stay gem English.
    assert_includes response.body, "Filters"
  end

  test "english chrome on sections index and screen table stays literal" do
    sign_in_admin_user

    get "/admin/sections", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "Admin sections"
    assert_includes response.body, "Browse the sections available in this admin context"
    assert_includes response.body, "Search screens and sections"

    get "/admin/screens/api_requests/table", params: { anchor_url: root_url },
                                            headers: { "Turbo-Frame" => "screen-table" }

    assert_response :success
    assert_includes response.body, "Columns"
    assert_includes response.body, "Choose table columns"
    assert_includes response.body, "Table columns"
    assert_includes response.body, "Reset"
    assert_includes response.body, "Apply"
  end
end
