# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def test_default_mount_path
    assert_equal "/admin", RecordingStudioAdmin::Configuration.new.default_mount_path
  end

  def test_merge_updates_known_keys_only
    config = RecordingStudioAdmin::Configuration.new

    config.merge!("default_mount_path" => "/backoffice", "unknown" => true)

    assert_equal "/backoffice", config.default_mount_path
  end
end
