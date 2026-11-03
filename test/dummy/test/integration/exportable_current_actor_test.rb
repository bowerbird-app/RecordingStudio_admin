# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ExportableCurrentActorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  test "signed-in export POST returns csv when current_actor is configured" do
    sign_in_export_user
    create_export_request!

    token = export_token_for("actor-export")

    post "/recording_studio_exportable/exports", params: {
      export_token: token,
      format: "csv",
      filters: { search: "actor-export" }
    }

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "/v1/actor-export"
  end

  test "export POST returns 403 without config.current_actor" do
    sign_in_export_user
    create_export_request!
    token = export_token_for("actor-export")
    configuration = RecordingStudioExportable.configuration
    original_current_actor = configuration.current_actor
    configuration.current_actor = lambda { |**|
      Current.actor if defined?(Current) && Current.respond_to?(:actor)
    }

    post "/recording_studio_exportable/exports", params: {
      export_token: token,
      format: "csv"
    }

    assert_response :forbidden
    assert_equal "Export is not available", response.body
  ensure
    configuration.current_actor = original_current_actor if defined?(configuration) && configuration
  end

  private

  def sign_in_export_user
    user = User.find_or_create_by!(email: "exportable-current-actor@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_admin_access_for_test!(recording: RecordingStudio.root_recording_for(admin_root), actor: user)
    sign_in user
  end

  def create_export_request!
    ApiRequest.delete_all
    ApiRequest.create!(
      path: "/v1/actor-export",
      method: "GET",
      status: 200,
      latency_ms: 12,
      created_at: Time.current,
      updated_at: Time.current
    )
  end

  def export_token_for(search)
    get "/admin/screens/api_requests/table", params: {
      search: search,
      columns: [ "path" ],
      columns_present: "1"
    }

    assert_response :success
    token_field = css_select('input[name="export_token"]').first
    assert token_field, "expected an export token from the admin table"
    token_field["value"]
  end
end
