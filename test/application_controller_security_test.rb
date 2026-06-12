# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_dispatch/testing/test_response"
require File.expand_path("../app/controllers/recording_studio_admin/application_controller", __dir__)

class ApplicationControllerSecurityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def setup
    @original_authentication_method = RecordingStudioAdmin.configuration.authentication_method
    @original_authorization_method = RecordingStudioAdmin.configuration.authorization_method
    @original_current_actor_method = RecordingStudioAdmin.configuration.current_actor_method
  end

  def teardown
    RecordingStudioAdmin.configuration.authentication_method = @original_authentication_method
    RecordingStudioAdmin.configuration.authorization_method = @original_authorization_method
    RecordingStudioAdmin.configuration.current_actor_method = @original_current_actor_method
  end

  def test_engine_controller_has_fail_closed_authentication_hook
    source = File.read(File.join(ROOT, "app/controllers/recording_studio_admin/application_controller.rb"))

    assert_includes source, "before_action :authenticate_recording_studio_admin!"
    assert_includes source, "before_action :authorize_recording_studio_admin!"
    assert_includes source, "head :unauthorized"
    assert_includes source, "head :forbidden"
    assert_includes source, "set_recording_studio_admin_current_actor"
  end

  def test_private_authentication_and_authorization_hooks_are_supported
    controller = build_controller do
      private

      def require_admin!
        @authenticated = true
      end

      def allow_admin!
        @authorized = true
      end
    end
    RecordingStudioAdmin.configuration.authentication_method = :require_admin!
    RecordingStudioAdmin.configuration.authorization_method = :allow_admin!

    controller.send(:authenticate_recording_studio_admin!)
    controller.send(:authorize_recording_studio_admin!)

    assert controller.instance_variable_get(:@authenticated)
    assert controller.instance_variable_get(:@authorized)
    assert_equal 200, controller.response.status
  end

  def test_missing_authorization_hook_fails_closed
    controller = build_controller
    RecordingStudioAdmin.configuration.authorization_method = :missing_admin_authorization!

    controller.send(:authorize_recording_studio_admin!)

    assert_equal 403, controller.response.status
  end

  def test_false_authorization_hook_fails_closed
    controller = build_controller do
      define_method(:reject_admin_access!) { false }
    end
    RecordingStudioAdmin.configuration.authorization_method = :reject_admin_access!

    controller.send(:authorize_recording_studio_admin!)

    assert_equal 403, controller.response.status
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

  private

  def build_controller(&)
    klass = Class.new(RecordingStudioAdmin::ApplicationController, &)
    klass.new.tap do |controller|
      controller.set_request! ActionDispatch::TestRequest.create
      controller.set_response! ActionDispatch::TestResponse.new
    end
  end
end
