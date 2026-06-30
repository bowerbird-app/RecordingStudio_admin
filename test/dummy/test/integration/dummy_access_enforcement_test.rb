# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class DummyAccessEnforcementTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  test "dummy pages return forbidden when user has no accessible roots" do
    user = User.find_or_create_by!(email: "no-access-user@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    Workspace.find_or_create_by!(name: "No Access Workspace")

    sign_in user

    get root_path

    assert_response :forbidden

    get docs_install_path

    assert_response :forbidden
  end

  test "dummy pages render when user has access to a root" do
    user = User.find_or_create_by!(email: "with-access-user@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    workspace = Workspace.find_or_create_by!(name: "With Access Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: user)

    sign_in user

    get root_path

    assert_response :success

    get docs_install_path

    assert_response :success
  end
end
