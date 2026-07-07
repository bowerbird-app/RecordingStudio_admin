# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_dispatch/testing/test_response"
require File.expand_path("../app/controllers/recording_studio_admin/application_controller", __dir__)
require File.expand_path("../app/controllers/recording_studio_admin/sections_controller", __dir__)
require File.expand_path("../app/controllers/recording_studio_admin/section_widgets_controller", __dir__)
require File.expand_path("../app/controllers/recording_studio_admin/screen_widgets_controller", __dir__)

class SectionsControllerTest < Minitest::Test
  ResolvedSection = Struct.new(:key, :title, :subtitle, :icon, :url, keyword_init: true)
  ResolvedItem = Struct.new(:type, :key, :title, :subtitle, :icon, :url, :search_text, :parent_key, keyword_init: true)

  def test_index_assigns_sections_and_filters_admin_items_by_search_query
    controller = build_controller(params: ActionController::Parameters.new(q: "user", type: "screens"))
    sections = [ResolvedSection.new(key: "users", title: "Users", subtitle: nil, icon: nil,
                                    url: "/admin/sections/users")]
    items = [
      ResolvedItem.new(type: :section, key: "users", title: "Users", subtitle: "People", icon: nil,
                       url: "/admin/sections/users", search_text: "section users people"),
      ResolvedItem.new(type: :screen, key: "user_sign_ins", title: "User sign-ins", subtitle: "Access", icon: nil,
                       url: "/admin/screens/user_sign_ins",
                       search_text: "screen user sign-ins access",
                       parent_key: "users"),
      ResolvedItem.new(type: :screen, key: "user_reviews", title: "User reviews", subtitle: "Reviews", icon: nil,
                       url: "/admin/screens/user_reviews",
                       search_text: "screen user reviews reviews",
                       parent_key: "users"),
      ResolvedItem.new(type: :screen, key: "api_requests", title: "API requests", subtitle: "Traffic", icon: nil,
                       url: "/admin/screens/api_requests", search_text: "screen api requests traffic")
    ]
    expected_context = Object.new

    expected_context.define_singleton_method(:available_admin_items) do |include:|
      raise "unexpected include" unless include == %i[sections screens]

      items
    end

    controller.define_singleton_method(:recording_studio_admin_context) { expected_context }

    with_singleton_stub(RecordingStudioAdmin, :resolve_sections, lambda { |context:|
      assert_same expected_context, context
      sections
    }) do
      controller.index
    end

    assert_same sections, controller.instance_variable_get(:@sections)
    assert_equal "user", controller.instance_variable_get(:@search_query)
    assert_equal "screens", controller.instance_variable_get(:@search_type)
    assert_same items, controller.instance_variable_get(:@admin_items)
    assert_equal %w[user_sign_ins user_reviews], controller.instance_variable_get(:@matching_admin_items).map(&:key)
    assert_equal(["In Users"], controller.instance_variable_get(:@search_result_groups).map do |group|
      group.fetch(:title)
    end)
    assert_equal %w[user_sign_ins user_reviews],
                 controller.instance_variable_get(:@search_result_groups).first.fetch(:items).map(&:key)
  end

  def test_show_uses_surface_root_section_when_key_is_absent
    controller = build_controller(params: ActionController::Parameters.new)
    expected_context = Struct.new(:root_admin_section_key).new("page_views")
    resolved_section = Object.new
    resolved_key = nil

    controller.define_singleton_method(:recording_studio_admin_context) { expected_context }

    with_singleton_stub(RecordingStudioAdmin, :resolve_section, lambda { |key:, context:, resolve_widgets:|
      resolved_key = key
      assert_equal "page_views", key
      assert_same expected_context, context
      assert_equal false, resolve_widgets
      resolved_section
    }) do
      controller.show
    end

    assert_equal "page_views", resolved_key
    assert_same resolved_section, controller.instance_variable_get(:@section)
  end

  def test_show_uses_explicit_section_key_when_present
    controller = build_controller(params: ActionController::Parameters.new(key: "users"))
    expected_context = Struct.new(:root_admin_section_key).new("page_views")
    resolved_key = nil

    controller.define_singleton_method(:recording_studio_admin_context) { expected_context }

    with_singleton_stub(RecordingStudioAdmin, :resolve_section, lambda { |key:, context:, resolve_widgets:|
      resolved_key = key
      assert_same expected_context, context
      assert_equal false, resolve_widgets
      Object.new
    }) do
      controller.show
    end

    assert_equal "users", resolved_key
  end

  def test_show_resolves_widget_values_when_async_widgets_are_disabled
    controller = build_controller(params: ActionController::Parameters.new(key: "users"))
    expected_context = Struct.new(:root_admin_section_key).new("page_views")
    original_enabled = RecordingStudioAdmin.configuration.async_widgets.enabled

    RecordingStudioAdmin.configuration.async_widgets.enabled = false
    controller.define_singleton_method(:recording_studio_admin_context) { expected_context }

    with_singleton_stub(RecordingStudioAdmin, :resolve_section, lambda { |key:, context:, resolve_widgets:|
      assert_equal "users", key
      assert_same expected_context, context
      assert_equal true, resolve_widgets
      Object.new
    }) do
      controller.show
    end
  ensure
    RecordingStudioAdmin.configuration.async_widgets.enabled = original_enabled
  end

  def test_section_widget_endpoint_resolves_widget_through_parent_section
    controller = build_controller(
      params: ActionController::Parameters.new(section_key: "users", widget_key: "widgets.users.total")
    )
    expected_context = Struct.new(:root_admin_section_key).new("page_views")
    resolved_widget = Object.new

    controller.define_singleton_method(:recording_studio_admin_context) { expected_context }
    controller.define_singleton_method(:render) do |partial:, locals:|
      @rendered_partial = partial
      @rendered_locals = locals
    end

    with_singleton_stub(RecordingStudioAdmin::Resolvers::SectionResolver, :resolve_widget,
                        lambda { |key:, widget_key:, view_variant:, context:|
                          assert_equal "users", key
                          assert_equal "widgets.users.total", widget_key
                          assert_nil view_variant
                          assert_same expected_context, context
                          resolved_widget
                        }) do
      controller.show
    end

    assert_equal "recording_studio_admin/shared/widget_frame", controller.instance_variable_get(:@rendered_partial)
    assert_equal({ parent: :section, parent_key: "users", widget: resolved_widget },
                 controller.instance_variable_get(:@rendered_locals))
  end

  def test_screen_widget_endpoint_resolves_widget_through_parent_screen
    controller = build_controller(
      params: ActionController::Parameters.new(screen_key: "users", widget_key: "widgets.users.total")
    )
    expected_context = Struct.new(:root_admin_section_key).new("page_views")
    resolved_widget = Object.new

    controller.define_singleton_method(:recording_studio_admin_context) { expected_context }
    controller.define_singleton_method(:render) do |partial:, locals:|
      @rendered_partial = partial
      @rendered_locals = locals
    end

    with_singleton_stub(RecordingStudioAdmin::Resolvers::ScreenResolver, :resolve_widget,
                        lambda { |key:, widget_key:, view_variant:, context:|
                          assert_equal "users", key
                          assert_equal "widgets.users.total", widget_key
                          assert_nil view_variant
                          assert_same expected_context, context
                          resolved_widget
                        }) do
      controller.show
    end

    assert_equal "recording_studio_admin/shared/widget_frame", controller.instance_variable_get(:@rendered_partial)
    assert_equal({ parent: :screen, parent_key: "users", widget: resolved_widget },
                 controller.instance_variable_get(:@rendered_locals))
  end

  private

  def build_controller(params:)
    controller_class = if params.key?(:section_key)
                         RecordingStudioAdmin::SectionWidgetsController
                       elsif params.key?(:screen_key)
                         RecordingStudioAdmin::ScreenWidgetsController
                       else
                         RecordingStudioAdmin::SectionsController
                       end

    controller_class.new.tap do |controller|
      controller.set_request! ActionDispatch::TestRequest.create
      controller.set_response! ActionDispatch::TestResponse.new
      controller.define_singleton_method(:params) { params }
    end
  end
end
