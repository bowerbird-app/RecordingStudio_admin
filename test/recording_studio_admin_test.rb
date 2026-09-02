# frozen_string_literal: true

require "test_helper"

class RecordingStudioAdminTest < Minitest::Test
  def test_version_matches_the_current_release
    assert_equal "2.0.2", ::RecordingStudioAdmin::VERSION
  end

  def test_lockfiles_match_the_current_release
    root = File.expand_path("..", __dir__)
    version = ::RecordingStudioAdmin::VERSION

    %w[Gemfile.lock test/dummy/Gemfile.lock].each do |relative|
      lockfile = File.read(File.join(root, relative))
      assert_includes lockfile, "recording_studio_admin (#{version})", relative
    end
  end

  def test_engine_exists
    assert_kind_of Class, ::RecordingStudioAdmin::Engine
  end

  def test_public_registry_api_exists
    assert_respond_to RecordingStudioAdmin, :register_screen
    assert_respond_to RecordingStudioAdmin, :register_section
    assert_respond_to RecordingStudioAdmin, :resolve_screen
    assert_respond_to RecordingStudioAdmin, :resolve_widget
    assert_respond_to RecordingStudioAdmin, :available_widgets
  end
end
