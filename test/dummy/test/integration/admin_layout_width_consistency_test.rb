# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminLayoutWidthConsistencyTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "admin-layout-width@example.com") do |record|
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

  test "admin section routes use the same uncapped width as admin screens" do
    sign_in_admin_user

    get "/admin/screens/api_requests", params: { anchor_url: root_url }
    assert_response :success
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
    assert_includes response.body, "max-w-6xl"

    get "/admin/sections", params: { anchor_url: root_url }
    assert_response :success
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
    assert_includes response.body, "max-w-6xl"
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"

    get "/admin/sections/users", params: { anchor_url: root_url }
    assert_response :success
    assert_includes response.body, 'data-recording-studio-default-layout="true"'
    assert_includes response.body, "max-w-6xl"
    assert_includes response.body, "mx-auto flex w-full flex-col gap-6"
  end
end
