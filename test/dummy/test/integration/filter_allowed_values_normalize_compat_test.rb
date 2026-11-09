# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class FilterAllowedValuesNormalizeCompatTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  module OneArgSelectFilterNormalize
    def normalize(params)
      super
    end
  end

  test "a one-arg SelectFilter normalize override still renders a screen" do
    user = User.find_or_create_by!(email: "filter-allowed-values-normalize-compat@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_admin_access_for_test!(recording: RecordingStudio.root_recording_for(admin_root), actor: user)
    sign_in user

    RecordingStudioAdmin::Filters::SelectFilter.prepend(OneArgSelectFilterNormalize)

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    refute_includes response.body, "ArgumentError"
  end
end
