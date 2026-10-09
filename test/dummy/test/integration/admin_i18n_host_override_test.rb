# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminI18nHostOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

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

    get "/admin/sections", params: { anchor_url: root_url }

    assert_response :success
    assert_includes response.body, "HOST Browse the sections available in this admin context"
    refute_match(
      /(?<!HOST )Browse the sections available in this admin context/,
      response.body
    )
    assert_equal @original_load_path, I18n.load_path
  end

  test "dummy host override file is on the rails load path after the gem locale" do
    gem_locale = File.expand_path("../../../../config/locales/en.yml", __dir__)
    host_locale = File.expand_path("../../config/locales/recording_studio_admin.host_override.en.yml", __dir__)
    expanded = I18n.load_path.map { |path| File.expand_path(path) }

    assert_includes expanded, File.expand_path(gem_locale)
    assert_includes expanded, File.expand_path(host_locale)
    assert_operator expanded.index(File.expand_path(host_locale)), :>,
                    expanded.index(File.expand_path(gem_locale))
    assert_equal @original_load_path, I18n.load_path
  end
end
