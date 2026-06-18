# frozen_string_literal: true

require "test_helper"
require_relative "../app/helpers/recording_studio_admin/widget_rendering_helper"

class WidgetPresenterTest < Minitest::Test
  def test_uses_injected_link_policy_for_admin_specific_link_behavior
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(link_to: "/admin/screens/activity", view_variant: :compact),
      link_policy: ->(url) { "#{url}?anchor_url=%2Forigin" }
    )

    assert presenter.compact?
    assert_equal "/admin/screens/activity?anchor_url=%2Forigin", presenter.href
    assert_equal "/admin/screens/activity?anchor_url=%2Forigin", presenter.compact_href
    assert_equal "Open Activity", presenter.compact_tooltip_text
  end

  def test_falls_back_to_safe_href_without_admin_controller_helpers
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(link_to: "javascript:alert(1)")
    )

    assert_equal "#", presenter.href
  end

  def test_reads_display_metadata_from_symbol_or_string_keys
    symbol_presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(metadata: { period_label: "This week", progress_value: 8 })
    )
    string_presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(metadata: { "unit_label" => "requests", "progress_max" => 12 })
    )

    assert_equal "This week", symbol_presenter.period_label
    assert_equal 8, symbol_presenter.progress_value
    assert_equal "requests", string_presenter.unit_label
    assert_equal 12, string_presenter.progress_max
  end

  def test_builds_mini_chart_options_without_overwriting_custom_options
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(chart_options: { chart: { height: 96 }, colors: ["#123456"] })
    )
    options = presenter.mini_chart_options

    assert_equal true, options.dig(:chart, :sparkline, :enabled)
    assert_equal false, options.dig(:chart, :toolbar, :show)
    assert_equal 96, options.dig(:chart, :height)
    assert_equal ["#123456"], options[:colors]
  end

  def test_helper_renders_full_widget_body_and_chart_with_custom_safe_link_policy
    view = FakeWidgetView.new
    widget = resolved_widget(link_to: "/reports", view_variant: nil)

    assert_equal "rendered recording_studio_admin/shared/widget", view.render_recording_studio_widget(widget)
    assert_equal "recording_studio_admin/shared/widget", view.rendered_partial
    assert_equal "/reports", view.rendered_locals.fetch(:presenter).href

    assert_equal "rendered recording_studio_admin/shared/widgets/chart", view.render_recording_studio_chart_widget(widget)
    assert_equal "recording_studio_admin/shared/widgets/chart", view.rendered_partial

    assert_equal "rendered recording_studio_admin/shared/widgets/chart", view.render_recording_studio_widget_body(widget)
    assert_equal "recording_studio_admin/shared/widgets/chart", view.rendered_partial
  end

  private

  def resolved_widget(**overrides)
    defaults = {
      key: "activity.widgets.total",
      type: :chart,
      title: "Activity",
      subtitle: "Recent activity",
      description: nil,
      value: 42,
      change: "+10%",
      change_good_when: :up,
      link_to: "/admin/screens/activity",
      link_label: "Activity",
      series: [{ name: "Activity", data: [1, 2, 3] }],
      chart_type: :area,
      chart_options: {},
      list_options: {},
      items: nil,
      rows: nil,
      metadata: {},
      view_variant: :compact,
      show_metric: true,
      show_change: true,
      show_period: true
    }

    RecordingStudioAdmin::Results::ResolvedWidget.new(**defaults.merge(overrides))
  end

  class FakeWidgetView
    include RecordingStudioAdmin::WidgetRenderingHelper

    attr_reader :rendered_partial, :rendered_locals

    def render(partial:, locals:)
      @rendered_partial = partial
      @rendered_locals = locals
      "rendered #{partial}"
    end
  end
end