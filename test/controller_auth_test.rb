# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_dispatch/testing/test_response"

class ControllerAuthTest < Minitest::Test
  CurrentStub = Struct.new(:actor) do
    class << self
      attr_accessor :actor
    end
  end

  ROOT = File.expand_path("..", __dir__)
  GENERATED_BASE_CONTROLLER = File.join(
    ROOT,
    "lib/generators/recording_studio_admin/admin_root/templates",
    "app/controllers/admin/base_controller.rb"
  )

  def setup
    @original_authentication_method = RecordingStudioAdmin.configuration.authentication_method
    @original_current_actor_method = RecordingStudioAdmin.configuration.current_actor_method
    @original_surfaces = RecordingStudioAdmin.configuration.surfaces.dup
  end

  def teardown
    RecordingStudioAdmin.configuration.authentication_method = @original_authentication_method
    RecordingStudioAdmin.configuration.current_actor_method = @original_current_actor_method
    RecordingStudioAdmin.configuration.surfaces.clear
    @original_surfaces.each do |key, surface|
      RecordingStudioAdmin.configuration.surfaces[key] = surface
    end
  end

  def test_exposes_controller_auth_as_a_reusable_concern
    assert defined?(RecordingStudioAdmin::ControllerAuth)
    assert_includes RecordingStudioAdmin::ControllerAuth.singleton_class.ancestors,
                    ActiveSupport::Concern
  end

  def test_generated_base_controller_includes_controller_auth
    template = File.read(GENERATED_BASE_CONTROLLER)

    assert_includes template, "include RecordingStudioAdmin::ControllerAuth"
    assert_includes template, "before_action :set_recording_studio_admin_current_actor"
    assert_includes template, "authenticate_recording_studio_admin!"
    assert_includes template, "current_actor: current_actor"
    assert_includes template, "surface: recording_studio_admin_surface"
    assert_includes template, "!Current.actor.nil?"
    assert_includes template, "return if Current.respond_to?(:actor) && !Current.actor.nil?"
    refute_includes template, "RecordingStudioAdmin.configuration.authentication_method"
    refute_includes template, "RecordingStudioAdmin.configuration.current_actor_method"
  end

  def test_generated_controller_honors_per_area_authentication_override
    RecordingStudioAdmin.configuration.authentication_method = :require_admin!
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats", authentication_method: :require_stats!)
    controller = build_generated_controller(path: "/stats", script_name: "/stats") do
      private

      def require_admin!
        @authenticated_for_admin = true
      end

      def require_stats!
        @authenticated_for_stats = true
      end
    end

    controller.send(:authenticate_admin_user!)

    assert controller.instance_variable_get(:@authenticated_for_stats)
    refute controller.instance_variable_get(:@authenticated_for_admin)
  end

  def test_generated_controller_falls_back_to_global_authentication
    RecordingStudioAdmin.configuration.authentication_method = :require_admin!
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats")
    controller = build_generated_controller(path: "/stats", script_name: "/stats") do
      private

      def require_admin!
        @authenticated_for_admin = true
      end
    end

    controller.send(:authenticate_admin_user!)

    assert controller.instance_variable_get(:@authenticated_for_admin)
  end

  def test_generated_controller_honors_per_area_current_actor_method
    RecordingStudioAdmin.configuration.current_actor_method = :global_actor
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats", current_actor_method: :stats_actor)
    controller = build_generated_controller(path: "/stats", script_name: "/stats") do
      def global_actor
        :global
      end

      def stats_actor
        :stats
      end
    end

    assert_equal :stats, controller.send(:current_actor)
  end

  def test_generated_controller_falls_back_to_global_current_actor_method
    RecordingStudioAdmin.configuration.current_actor_method = :global_actor
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats")
    controller = build_generated_controller(path: "/stats", script_name: "/stats") do
      def global_actor
        :global
      end
    end

    assert_equal :global, controller.send(:current_actor)
  end

  def test_generated_current_actor_falls_back_to_configured_method_when_nil
    controller = build_generated_controller do
      def signed_in_actor
        :from_method
      end
    end
    RecordingStudioAdmin.configuration.current_actor_method = :signed_in_actor

    with_current_stub(actor: nil) do
      assert_equal :from_method, controller.send(:current_actor)
    end
  end

  def test_generated_set_current_actor_assigns_when_nil
    RecordingStudioAdmin.configuration.current_actor_method = :global_actor
    RecordingStudioAdmin.configuration.surface(:stats, path: "/stats", current_actor_method: :stats_actor)
    controller = build_generated_controller(path: "/stats", script_name: "/stats") do
      def global_actor
        :global
      end

      def stats_actor
        :stats
      end
    end

    with_current_stub(actor: nil) do
      controller.send(:set_recording_studio_admin_current_actor)

      assert_equal :stats, Current.actor
    end
  end

  def test_generated_set_current_actor_does_not_overwrite_host_set_actor
    RecordingStudioAdmin.configuration.current_actor_method = :signed_in_actor
    controller = build_generated_controller do
      def signed_in_actor
        :from_method
      end
    end

    with_current_stub(actor: :host_set) do
      controller.send(:set_recording_studio_admin_current_actor)

      assert_equal :host_set, Current.actor
    end
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

  def build_generated_controller(path: "/admin", script_name: "", &)
    host_application_controller = Class.new(ActionController::Base)
    klass = Class.new(host_application_controller) do
      include RecordingStudioAdmin::ControllerAuth

      def authenticate_admin_user!
        authenticate_recording_studio_admin!
      end

      def set_recording_studio_admin_current_actor
        return unless defined?(Current) && Current.respond_to?(:actor=)
        return if Current.respond_to?(:actor) && !Current.actor.nil?

        Current.actor = configured_current_actor
      end

      def current_actor
        return Current.actor if defined?(Current) && Current.respond_to?(:actor) && !Current.actor.nil?

        configured_current_actor
      end
    end
    klass.class_eval(&) if block_given?
    klass.new.tap do |controller|
      controller.set_request! ActionDispatch::TestRequest.create("PATH_INFO" => path, "SCRIPT_NAME" => script_name)
      controller.set_response! ActionDispatch::TestResponse.new
    end
  end
end
