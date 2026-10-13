# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

# Proves a host nested `recording_studio.admin.*` override in
# config/locales wins over gem English on a real page. Uses
# screens.filters.date_presets.last_year (JSON blob on filter screens)
# so other screen assertions keep default English. Does not touch
# I18n.load_path.
class AdminI18nBootOrderHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  HOST_LAST_YEAR = "HOST Last year"
  LAST_YEAR_KEY = "recording_studio.admin.screens.filters.date_presets.last_year"
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_admin_host.en.yml")

  def setup
    @original_load_path = I18n.load_path.dup
  end

  def teardown
    assert_equal @original_load_path, I18n.load_path,
                 "tests must not leave I18n.load_path modified"
  end

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "admin-i18n-boot-order@example.com") do |record|
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

  test "host nested locale override wins on screen filter date preset labels" do
    assert File.exist?(BOOT_HOST_LOCALE), "expected host override file at #{BOOT_HOST_LOCALE}"
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_LAST_YEAR

    sign_in_admin_user

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "data-recording-studio-admin--screen-filters-date-preset-labels-value"
    assert_includes response.body, "Today"
    # FlatPack's own date-picker also ships English "Last year"; assert the gem
    # Stimulus JSON blob specifically carries the host override.
    assert_includes response.body, 'last_year&quot;:&quot;HOST Last year&quot;'
    assert_equal HOST_LAST_YEAR, I18n.t(LAST_YEAR_KEY, raise: true)
    assert_equal @original_load_path, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"
  end
end
