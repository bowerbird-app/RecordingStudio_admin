# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_dispatch/testing/test_response"
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
  end

  def teardown
    RecordingStudioAdmin.configuration.authentication_method = @original_authentication_method
    RecordingStudioAdmin.configuration.current_actor_method = @original_current_actor_method
  end

  def test_engine_controller_has_fail_closed_authentication_hook
    source = File.read(File.join(ROOT, "app/controllers/recording_studio_admin/application_controller.rb"))

    assert_includes source, "before_action :authenticate_recording_studio_admin!"
    assert_includes source, "head :unauthorized"
    assert_includes source, "head :forbidden"
    assert_includes source, "set_recording_studio_admin_current_actor"
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
    controller.set_request! ActionDispatch::TestRequest.create("PATH_INFO" => "/admin/screens/api_requests",
                                                               "QUERY_STRING" => "anchor_url=http%3A%2F%2Fwww.example.com%2F")
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

  def build_controller(&)
    klass = Class.new(RecordingStudioAdmin::ApplicationController, &)
    klass.new.tap do |controller|
      controller.set_request! ActionDispatch::TestRequest.create
      controller.set_response! ActionDispatch::TestResponse.new
    end
  end
end
