# frozen_string_literal: true

require "test_helper"
require "action_controller"
require "action_dispatch/testing/test_response"
require File.expand_path("../app/controllers/recording_studio_admin/application_controller", __dir__)
require File.expand_path("../app/controllers/recording_studio_admin/screens_controller", __dir__)
require File.expand_path("../app/controllers/recording_studio_admin/screen_widgets_controller", __dir__)
require File.expand_path("../app/controllers/recording_studio_admin/section_widgets_controller", __dir__)

class ScreensControllerTest < Minitest::Test
  HOST = "http://test.host"

  def test_table_endpoint_sends_a_page_visit_to_the_screen_page
    controller = build_screens_controller(
      params: { key: "recording_studio_users" },
      query_string: "sort=email&direction=asc"
    )

    controller.table

    assert_equal 302, controller.response.status
    assert_equal "#{HOST}/admin/screens/recording_studio_users?direction=asc&sort=email",
                 controller.response.location
  end

  def test_chart_endpoint_sends_a_page_visit_to_the_screen_page
    controller = build_screens_controller(params: { key: "recording_studio_users" })

    controller.chart

    assert_equal "#{HOST}/admin/screens/recording_studio_users", controller.response.location
  end

  def test_table_count_endpoint_sends_a_page_visit_to_the_screen_page
    controller = build_screens_controller(params: { key: "recording_studio_users" })

    controller.table_count

    assert_equal "#{HOST}/admin/screens/recording_studio_users", controller.response.location
  end

  def test_table_endpoint_renders_the_frame_for_a_turbo_frame_request
    controller = build_screens_controller(
      params: { key: "recording_studio_users" },
      turbo_frame: "screen-table"
    )
    resolved_screen = Object.new

    with_singleton_stub(RecordingStudioAdmin, :resolve_screen, ->(**) { resolved_screen }) do
      controller.table
    end

    assert_nil controller.response.location
    assert_equal "recording_studio_admin/screens/table_frame", controller.rendered_partial
    assert_same resolved_screen, controller.rendered_locals.fetch(:screen)
  end

  def test_table_endpoint_renders_the_frame_for_an_infinite_pagination_request
    controller = build_screens_controller(
      params: { key: "recording_studio_users" },
      query_string: "page=2",
      xhr: true
    )
    resolved_screen = Object.new

    with_singleton_stub(RecordingStudioAdmin, :resolve_screen, ->(**) { resolved_screen }) do
      controller.table
    end

    assert_nil controller.response.location
    assert_equal "recording_studio_admin/screens/table_frame", controller.rendered_partial
  end

  def test_screen_widget_endpoint_sends_a_page_visit_to_the_screen_page
    controller = build_widget_controller(
      RecordingStudioAdmin::ScreenWidgetsController,
      params: { screen_key: "recording_studio_users", widget_key: "widgets.users.total" },
      query_string: "widget_render_variant=compact&preset_key=this_week"
    )

    controller.show

    assert_equal "#{HOST}/admin/screens/recording_studio_users?preset_key=this_week", controller.response.location
  end

  def test_section_widget_endpoint_sends_a_page_visit_to_the_section_page
    controller = build_widget_controller(
      RecordingStudioAdmin::SectionWidgetsController,
      params: { section_key: "users", widget_key: "widgets.users.total" }
    )

    controller.show

    assert_equal "#{HOST}/admin/sections/users", controller.response.location
  end

  private

  def build_screens_controller(params:, query_string: "", turbo_frame: nil, xhr: false)
    build_controller(
      RecordingStudioAdmin::ScreensController,
      params: params,
      query_string: query_string,
      turbo_frame: turbo_frame,
      xhr: xhr
    )
  end

  def build_widget_controller(controller_class, params:, query_string: "")
    build_controller(controller_class, params: params, query_string: query_string)
  end

  def build_controller(controller_class, params:, query_string:, turbo_frame: nil, xhr: false)
    env = { "QUERY_STRING" => query_string }
    env["HTTP_TURBO_FRAME"] = turbo_frame if turbo_frame
    env["HTTP_X_REQUESTED_WITH"] = "XMLHttpRequest" if xhr

    controller_class.new.tap do |controller|
      controller.set_request! ActionDispatch::TestRequest.create(env)
      controller.set_response! ActionDispatch::TestResponse.new
      controller.response.request = controller.request
      controller.define_singleton_method(:params) { ActionController::Parameters.new(params) }
      controller.define_singleton_method(:recording_studio_admin_context) { AdminContextStub.new }
      controller.singleton_class.attr_reader :rendered_partial, :rendered_locals
      controller.define_singleton_method(:render) do |partial:, locals:|
        @rendered_partial = partial
        @rendered_locals = locals
      end
    end
  end

  class AdminContextStub
    def admin_screen_path(key)
      "/admin/screens/#{key}"
    end

    def admin_section_path(key)
      "/admin/sections/#{key}"
    end
  end
end
