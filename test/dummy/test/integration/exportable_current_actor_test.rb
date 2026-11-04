# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ExportableCurrentActorTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  test "issuing an admin export token does not mutate trusted_export_sources" do
    sign_in_export_user
    create_export_request!
    configuration = RecordingStudioExportable.configuration
    sources_before = Array(configuration.trusted_export_sources).map(&:to_s)

    token = export_token_for("actor-export")

    assert token.present?
    assert_equal sources_before, Array(configuration.trusted_export_sources).map(&:to_s)
  end

  test "issuing an admin export token returns none when the source is not allowlisted" do
    sign_in_export_user
    create_export_request!
    configuration = RecordingStudioExportable.configuration
    original_sources = Array(configuration.trusted_export_sources).dup
    configuration.trusted_export_sources = original_sources.reject { |source| source.to_s == "recording_studio_admin" }
    sources_before = Array(configuration.trusted_export_sources).map(&:to_s)

    refute_includes sources_before, "recording_studio_admin"

    get "/admin/screens/api_requests/table", params: {
      search: "actor-export",
      columns: [ "path" ],
      columns_present: "1"
    }

    assert_response :success
    token_field = css_select('input[name="export_token"]').first
    token = token_field && token_field["value"]
    assert token.blank?
    assert_equal sources_before, Array(configuration.trusted_export_sources).map(&:to_s)
    refute_includes Array(configuration.trusted_export_sources).map(&:to_s), "recording_studio_admin"
  ensure
    configuration.trusted_export_sources = original_sources if defined?(configuration) && configuration
  end

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
