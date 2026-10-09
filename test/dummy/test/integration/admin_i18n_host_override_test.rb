# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminI18nHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  HOST_OVERRIDE_LOCALE = File.expand_path(
    "../locales/recording_studio_admin.host_override.en.yml",
    __dir__
  ).freeze

  def setup
    @original_load_path = I18n.load_path.dup
  end

  def teardown
    I18n.load_path = @original_load_path
    I18n.reload!
  end

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "admin-i18n-host-override@example.com") do |record|
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

  test "host locale file overrides gem english on a real admin page" do
    sign_in_admin_user

    begin
      I18n.load_path << HOST_OVERRIDE_LOCALE
      I18n.reload!

      get "/admin/sections", params: { anchor_url: root_url, q: "zzzz-no-match-host-override" }

      assert_response :success
      assert_includes response.body, "HOST No admin screens or sections match that search."
      refute_match(/(?<!HOST )No admin screens or sections match that search\./, response.body)
    ensure
      I18n.load_path = @original_load_path.dup
      I18n.reload!
      assert_equal @original_load_path, I18n.load_path
    end
  end

  test "without the test-only override the gem english empty search still renders" do
    sign_in_admin_user

    get "/admin/sections", params: { anchor_url: root_url, q: "zzzz-no-match-default-english" }

    assert_response :success
    assert_includes response.body, "No admin screens or sections match that search."
    refute_includes response.body, "HOST No admin screens or sections match that search."
    assert_equal @original_load_path, I18n.load_path
  end
end
