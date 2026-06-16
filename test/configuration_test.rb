# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def test_defaults
    config = RecordingStudioAdmin::Configuration.new

    assert_equal "/admin", config.default_mount_path
    assert_equal :authenticate_user!, config.authentication_method
    assert_equal :current_user, config.current_actor_method
    assert_equal :recording_studio_admin_access_recording, config.access_recording_method
    assert_nil config.access_recording_resolver
    assert_equal :view, config.required_access_role
    assert_equal 1_000, config.max_page
  end

  def test_merge_updates_known_keys_only
    config = RecordingStudioAdmin::Configuration.new

    config.merge!("default_mount_path" => "/backoffice", "unknown" => true)

    assert_equal "/backoffice", config.default_mount_path
  end
end
