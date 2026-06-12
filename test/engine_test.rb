# frozen_string_literal: true

require "test_helper"

class EngineTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_engine_isolates_recording_studio_admin_namespace
    content = File.read(File.join(ROOT, "lib/recording_studio_admin/engine.rb"))

    assert_includes content, "isolate_namespace RecordingStudioAdmin"
  end

  def test_routes_are_explicit_without_catch_all
    content = File.read(File.join(ROOT, "config/routes.rb"))

    assert_includes content, 'root "sections#show", defaults: { key: "root" }'
    assert_includes content, 'get "sections/:key"'
    assert_includes content, 'get "screens/:key"'
    refute_match(/\*path|\*key/, content)
  end
end
