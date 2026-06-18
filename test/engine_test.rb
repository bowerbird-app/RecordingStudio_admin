# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"

class EngineTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_engine_isolates_recording_studio_admin_namespace
    content = File.read(File.join(ROOT, "lib/recording_studio_admin/engine.rb"))

    assert_includes content, "isolate_namespace RecordingStudioAdmin"
  end

  def test_routes_are_explicit_without_catch_all
    content = File.read(File.join(ROOT, "config/routes.rb"))

    assert_includes content, 'root "sections#show"'
    assert_includes content, 'get "sections", to: "sections#index", as: :sections'
    assert_includes content, 'get "sections/:key"'
    assert_includes content, 'get "screens/:key"'
    refute_includes content, 'resources/:key'
    refute_match(/\*path|\*key/, content)
  end

  def test_route_helper_mounts_named_surface
    original_surfaces = RecordingStudioAdmin.configuration.surfaces.dup
    mounted = []
    mapper = Class.new do
      include RecordingStudioAdmin::Routing

      define_method(:initialize) { |mounted_routes| @mounted_routes = mounted_routes }
      define_method(:mount) { |engine, at:, as:| @mounted_routes << [engine, at, as] }
    end.new(mounted)

    mapper.recording_studio_admin_for(:stats, at: "/stats", root_section: :page_views)

    assert_equal [[RecordingStudioAdmin::Engine, "/stats", "recording_studio_admin_stats"]], mounted
    surface = RecordingStudioAdmin.configuration.surface_for(:stats)
    assert_equal "/stats", surface.path
    assert_equal "page_views", surface.root_section
  ensure
    RecordingStudioAdmin.configuration.surfaces.clear
    original_surfaces.each { |key, surface| RecordingStudioAdmin.configuration.surfaces[key] = surface }
  end

  def test_engine_load_config_initializer_merges_yaml_when_present
    initializer = RecordingStudioAdmin::Engine.initializers.find { |entry| entry.name == "recording_studio_admin.load_config" }
    refute_nil initializer

    Dir.mktmpdir do |dir|
      config_path = File.join(dir, "config")
      FileUtils.mkdir_p(config_path)
      File.write(File.join(config_path, "recording_studio_admin.yml"), "engine_layout: admin_layout\n")

      app = Struct.new(:root) do
        def config_for(_key)
          { "engine_layout" => "admin_layout" }
        end
      end.new(Pathname.new(dir))

      original_layout = RecordingStudioAdmin.configuration.engine_layout
      initializer.block.call(app)

      assert_equal "admin_layout", RecordingStudioAdmin.configuration.engine_layout
    ensure
      RecordingStudioAdmin.configuration.engine_layout = original_layout
    end
  end

  def test_engine_routing_initializer_includes_routing_module
    initializer = RecordingStudioAdmin::Engine.initializers.find { |entry| entry.name == "recording_studio_admin.routing" }
    refute_nil initializer

    initializer.block.call

    assert_includes ActionDispatch::Routing::Mapper.included_modules, RecordingStudioAdmin::Routing
  end
end
