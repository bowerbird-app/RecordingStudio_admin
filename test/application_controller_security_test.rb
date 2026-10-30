# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_dispatch/testing/test_response"
require File.join(
  Gem.loaded_specs.fetch("recording_studio").full_gem_path,
  "app/helpers/recording_studio/layout_helper"
)
require File.expand_path("../app/controllers/recording_studio_admin/application_controller", __dir__)

class ApplicationControllerSecurityTest < Minitest::Test
  CurrentStub = Struct.new(:actor) do
    class << self
      attr_accessor :actor
    end
  end

  ROOT = File.expand_path("..", __dir__)

  def setup
    @original_authentication_method = RecordingStudioAdmin.configuration.authentication_method
    @original_current_actor_method = RecordingStudioAdmin.configuration.current_actor_method
    @original_current_root_recording_resolver = RecordingStudioAdmin.configuration.current_root_recording_resolver
    @original_layout = RecordingStudioAdmin.configuration.layout
    @original_recording_studio_layout = RecordingStudio.configuration.layout
    RecordingStudio.configuration.layout = nil
    @original_surfaces = RecordingStudioAdmin.configuration.surfaces.dup
  end

  def teardown
    RecordingStudioAdmin.configuration.authentication_method = @original_authentication_method
    RecordingStudioAdmin.configuration.current_actor_method = @original_current_actor_method
    RecordingStudioAdmin.configuration.current_root_recording_resolver = @original_current_root_recording_resolver
    RecordingStudioAdmin.configuration.layout = @original_layout
    RecordingStudio.configuration.layout = @original_recording_studio_layout
    RecordingStudioAdmin.configuration.surfaces.clear
    @original_surfaces.each do |key, surface|
      RecordingStudioAdmin.configuration.surfaces[key] = surface
    end
  end

  def test_engine_controller_has_fail_closed_authentication_hook
    source = File.read(File.join(ROOT, "app/controllers/recording_studio_admin/application_controller.rb"))

    assert_includes source, "recording_studio_layout"
    assert_includes source, "RecordingStudioAdmin.configuration.layout_for(recording_studio_admin_surface)"
    assert_includes source, "before_action :authenticate_recording_studio_admin!"
    assert_includes source, "head :unauthorized"
    assert_includes source, "head :forbidden"
    assert_includes source, "set_recording_studio_admin_current_actor"
  end

  def test_layout_uses_configuration
    controller = build_controller
    RecordingStudioAdmin.configuration.layout = "flat_pack_sidebar"

    assert_equal "flat_pack_sidebar", controller.send(:recording_studio_resolved_layout)
    refute controller.send(:recording_studio_admin_default_layout?)
  end

  def test_nil_layout_falls_through_to_recording_studio_then_the_default_name
    controller = build_controller
    RecordingStudioAdmin.configuration.layout = nil
    RecordingStudio.configuration.layout = nil

    assert_equal "recording_studio/default_layout", controller.send(:recording_studio_resolved_layout)
    assert controller.send(:recording_studio_admin_default_layout?)

    RecordingStudio.configuration.layout = "host_pages"

    assert_equal "host_pages", controller.send(:recording_studio_resolved_layout)
    refute controller.send(:recording_studio_admin_default_layout?)
  end

  def test_current_root_recording_uses_configured_resolver_including_nil
    staff_controller = build_controller
    staff_root = Object.new
    RecordingStudioAdmin.configuration.current_root_recording_resolver = lambda { |context|
      staff_root if context.controller.equal?(staff_controller)
    }

    assert_same staff_root, staff_controller.current_root_recording

    RecordingStudioAdmin.configuration.current_root_recording_resolver = ->(_context) {}
    ignored_controller = build_controller

    assert_nil ignored_controller.current_root_recording
  end

  def test_unset_current_root_recording_uses_root_switchable_without_controller_support
    assert_includes RecordingStudioAdmin::ApplicationController.public_instance_methods, :current_root_recording

    controller = build_controller
    if defined?(::RecordingStudio::RootSwitchable::ControllerSupport)
      refute_includes controller.class.ancestors, RecordingStudio::RootSwitchable::ControllerSupport
    end

    product_root = Object.new
    with_root_switchable_class_method(product_root) do
      assert_nil RecordingStudioAdmin.configuration.current_root_recording_resolver
      assert_same product_root, controller.current_root_recording
    end
  end

  def test_current_root_recording_resolver_can_be_overridden_by_surface
    product_root = Object.new
    RecordingStudioAdmin.configuration.current_root_recording_resolver = ->(_context) { product_root }
    RecordingStudioAdmin.configuration.surface(
      :stats,
      path: "/stats",
      current_root_recording_resolver: ->(_context) {}
    )
    controller = build_controller(path: "/stats/sections/page_views", script_name: "/stats")

    assert_nil controller.current_root_recording
  end

  def test_false_layout_renders_no_layout
    controller = build_controller
    RecordingStudioAdmin.configuration.layout = false

    assert_equal false, controller.send(:recording_studio_resolved_layout)
    refute controller.send(:recording_studio_admin_default_layout?)
  end

  def test_keyword_layout_callable_receives_the_controller
    seen = nil
    RecordingStudioAdmin.configuration.layout = lambda { |controller:|
      seen = controller
      "from_callable"
    }
    controller = build_controller

    assert_equal "from_callable", controller.send(:recording_studio_resolved_layout)
    assert_same controller, seen
  end

  def test_layout_can_be_overridden_by_surface
    RecordingStudioAdmin.configuration.layout = "admin_pages"
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats", layout: "stats_layout")
    controller = build_controller(path: "/stats/sections/page_views", script_name: "/stats")

    assert_equal "stats_layout", controller.send(:recording_studio_resolved_layout)
    refute controller.send(:recording_studio_admin_default_layout?)
  end

  def test_controllers_do_not_hardcode_a_recording_studio_layout
    gem_root = File.expand_path("..", __dir__)
    dummy_root = File.expand_path("dummy", __dir__)

    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(gem_root)
    assert_empty RecordingStudio::Layout.hardcoded_layout_paths(dummy_root)
  end

  def test_private_authentication_hook_is_supported
    controller = build_controller do
      private

      def require_admin!
        @authenticated = true
      end
    end
    RecordingStudioAdmin.configuration.authentication_method = :require_admin!

    controller.send(:authenticate_recording_studio_admin!)

    assert controller.instance_variable_get(:@authenticated)
    assert_equal 200, controller.response.status
  end

  def test_authentication_hook_can_be_overridden_by_surface
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats", authentication_method: :require_stats!)
    controller = build_controller(path: "/stats", script_name: "/stats") do
      private

      def require_stats!
        @authenticated_for_stats = true
      end
    end

    controller.send(:authenticate_recording_studio_admin!)

    assert controller.instance_variable_get(:@authenticated_for_stats)
  end

  def test_missing_authentication_hook_fails_closed
    controller = build_controller
    RecordingStudioAdmin.configuration.authentication_method = :missing_admin_authentication!

    controller.send(:authenticate_recording_studio_admin!)

    assert_equal 401, controller.response.status
  end

  def test_current_without_actor_writer_does_not_crash
    controller = build_controller
    original_current = Current if Object.const_defined?(:Current)
    Object.send(:remove_const, :Current) if Object.const_defined?(:Current)
    Object.const_set(:Current, Class.new)

    assert_silent { controller.send(:set_recording_studio_admin_current_actor) }
  ensure
    Object.send(:remove_const, :Current) if Object.const_defined?(:Current)
    Object.const_set(:Current, original_current) if defined?(original_current)
  end

  def test_set_current_actor_assigns_configured_actor_when_current_supports_writer
    controller = build_controller do
      def signed_in_actor
        :admin
      end
    end
    RecordingStudioAdmin.configuration.current_actor_method = :signed_in_actor

    with_current_stub do
      controller.send(:set_recording_studio_admin_current_actor)

      assert_equal :admin, Current.actor
    end
  end

  def test_recording_studio_admin_context_uses_controller_inputs_and_memoizes
    controller = build_controller do
      def signed_in_actor
        :owner
      end
    end
    RecordingStudioAdmin.configuration.current_actor_method = :signed_in_actor
    params = ActionController::Parameters.new(page: "2")
    view_context = Object.new
    controller.define_singleton_method(:params) { params }
    controller.define_singleton_method(:view_context) { view_context }

    context = controller.send(:recording_studio_admin_context)

    assert_same context, controller.send(:recording_studio_admin_context)
    assert_equal({ "page" => "2" }, context.params)
    assert_equal :owner, context.current_actor
    assert_same controller, context.controller
    assert_same controller, context.routes
    assert_same view_context, context.view_context
  end

  def test_context_uses_request_surface
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats", root_section: :page_views)
    controller = build_controller(path: "/stats", script_name: "/stats")

    context = controller.send(:recording_studio_admin_context)

    assert_equal "stats", context.surface.key
    assert_equal "page_views", context.root_admin_section_key
  end

  def test_page_nav_anchor_url_returns_default_for_blank_or_unsafe_values
    controller = build_controller
    params = ActionController::Parameters.new(anchor_url: "javascript:alert(1)")
    controller.define_singleton_method(:params) { params }

    assert_equal "/fallback", controller.send(:page_nav_anchor_url, default: "/fallback")

    params[:anchor_url] = "#"

    assert_equal "/fallback", controller.send(:page_nav_anchor_url, default: "/fallback")
  end

  def test_page_nav_anchor_url_allows_explicit_external_return_url
    controller = build_controller
    params = ActionController::Parameters.new(anchor_url: "https://example.test/origin")
    controller.define_singleton_method(:params) { params }

    assert_equal "https://example.test/origin", controller.send(:page_nav_anchor_url, default: "/fallback")
  end

  def test_preserve_anchor_url_merges_safe_relative_anchor_query
    controller = build_controller
    controller.define_singleton_method(:params) { ActionController::Parameters.new(anchor_url: "/origin?tab=overview") }

    assert_equal "/admin/screens/requests?anchor_url=%2Forigin%3Ftab%3Doverview",
                 controller.send(:preserve_anchor_url, "/admin/screens/requests")
    assert_equal "#", controller.send(:preserve_anchor_url, "https://example.test/reports")
  end

  def test_widget_link_url_suppresses_same_page_links_when_only_anchor_url_differs
    controller = build_controller
    controller.set_request! ActionDispatch::TestRequest.create(
      "PATH_INFO" => "/admin/screens/api_requests",
      "QUERY_STRING" => "anchor_url=http%3A%2F%2Fwww.example.com%2F"
    )
    controller.define_singleton_method(:params) { ActionController::Parameters.new(anchor_url: "http://www.example.com/") }

    assert_nil controller.send(:widget_link_url, "/admin/screens/api_requests")
    assert_equal "/admin/screens/users?anchor_url=http%3A%2F%2Fwww.example.com%2F",
                 controller.send(:widget_link_url, "/admin/screens/users")
    assert_equal "/admin/screens/api_requests?anchor_url=http%3A%2F%2Fwww.example.com%2F&page=2",
                 controller.send(:widget_link_url, "/admin/screens/api_requests?page=2")
  end

  def test_current_actor_prefers_current_constant_reader
    controller = build_controller do
      def signed_in_actor
        :configured
      end
    end
    RecordingStudioAdmin.configuration.current_actor_method = :signed_in_actor

    with_current_stub(actor: :from_current) do
      assert_equal :from_current, controller.send(:current_actor)
    end
  end

  def test_render_not_found_sets_not_found_status
    controller = build_controller

    controller.send(:render_not_found)

    assert_equal 404, controller.response.status
  end

  private

  def with_current_stub(actor: nil)
    original_current = Current if Object.const_defined?(:Current)
    Object.send(:remove_const, :Current) if Object.const_defined?(:Current)
    Object.const_set(:Current, CurrentStub)
    Current.actor = actor
    yield
  ensure
    Object.send(:remove_const, :Current) if Object.const_defined?(:Current)
    Object.const_set(:Current, original_current) if defined?(original_current)
  end

  def with_root_switchable_class_method(root)
    recording_studio = ::RecordingStudio
    had_constant = recording_studio.const_defined?(:RootSwitchable, false)
    original = recording_studio.const_get(:RootSwitchable) if had_constant
    switchable = Module.new
    switchable.define_singleton_method(:current_root_recording) { root }
    recording_studio.send(:remove_const, :RootSwitchable) if had_constant
    recording_studio.const_set(:RootSwitchable, switchable)
    yield
  ensure
    recording_studio.send(:remove_const, :RootSwitchable) if recording_studio.const_defined?(:RootSwitchable, false)
    recording_studio.const_set(:RootSwitchable, original) if had_constant
  end

  def build_controller(path: "/admin", script_name: "", &)
    klass = Class.new(RecordingStudioAdmin::ApplicationController, &)
    klass.new.tap do |controller|
      controller.set_request! ActionDispatch::TestRequest.create("PATH_INFO" => path, "SCRIPT_NAME" => script_name)
      controller.set_response! ActionDispatch::TestResponse.new
    end
  end
end
