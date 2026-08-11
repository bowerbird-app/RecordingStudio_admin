# frozen_string_literal: true

require "test_helper"
require "ostruct"
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

  def test_compact_list_preview_uses_count_period_and_text_summary
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(
        type: :list,
        value: nil,
        subtitle: "Latest five users",
        list_options: { compact_preview: :text_summary },
        items: [
          { text: "one@example.com" },
          { label: "two@example.com" },
          { text: "three@example.com" }
        ]
      )
    )

    assert_equal 3, presenter.compact_metric_value
    assert_nil presenter.compact_unit_label
    assert_nil presenter.compact_period_label
    assert_equal :text_summary, presenter.compact_list_preview_mode
    assert_equal "one@example.com, two@example.com +1", presenter.compact_list_text_summary
  end

  def test_compact_list_preview_prefers_metadata_period_and_avatar_names
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(
        type: :list,
        value: nil,
        metadata: { period_label: "This week" },
        list_options: { compact_preview: :visual_stack },
        items: [
          { text: "Ada", avatar: { name: "Ada Lovelace" } },
          { text: "Grace" }
        ]
      )
    )

    assert_equal "This week", presenter.compact_period_label
    assert presenter.compact_list_visual_stack?
    assert_equal "Ada Lovelace", presenter.list_item_avatar_name(presenter.compact_list_visual_items.first)
    assert_equal "Grace", presenter.list_item_avatar_name(presenter.compact_list_visual_items.last)
  end

  def test_compact_metric_value_shortens_large_numbers_with_exact_tooltip
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(value: 23_635.64)
    )

    assert_equal "23.6K", presenter.compact_metric_value
    assert_equal "23,635.64", presenter.compact_metric_tooltip_text
  end

  def test_compact_metric_value_leaves_small_numbers_without_tooltip
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(value: 999)
    )

    assert_equal 999, presenter.compact_metric_value
    assert_nil presenter.compact_metric_tooltip_text
  end

  def test_compact_metric_value_leaves_nonnumeric_values_without_tooltip
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(value: "pending")
    )

    assert_equal "pending", presenter.compact_metric_value
    assert_nil presenter.compact_metric_tooltip_text
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

  def test_compact_geo_mini_chart_options_hide_legend_scale
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(
        chart_type: :geo,
        chart_options: { geo: { map: "world", key_field: "iso2" }, chart: { height: 260 } }
      )
    )
    options = presenter.mini_chart_options

    assert_equal({ map: "world", key_field: "iso2" }, options[:geo])
    assert_equal "none", options[:legend]
    assert_nil options.dig(:chart, :sparkline, :enabled)
    assert_equal 260, options.dig(:chart, :height)
  end

  def test_full_size_geo_mini_chart_options_keep_legend_config
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(
        chart_type: :geo,
        chart_options: { geo: { map: "world", key_field: "iso2" }, legend: { textStyle: { color: "#000" } } },
        view_variant: nil
      )
    )
    options = presenter.mini_chart_options

    assert_equal({ map: "world", key_field: "iso2" }, options[:geo])
    assert_equal({ textStyle: { color: "#000" } }, options[:legend])
    assert_nil options.dig(:chart, :sparkline, :enabled)
  end

  def test_maps_legacy_geo_chart_type_to_flat_pack_geochart
    presenter = RecordingStudioAdmin::Widgets::Presenter.new(
      resolved_widget(chart_type: :geo)
    )

    assert_equal :geochart, presenter.chart_type
    assert_equal :geochart, presenter.mini_chart_type
  end

  def test_helper_renders_full_widget_body_and_chart_with_custom_safe_link_policy
    view = FakeWidgetView.new
    widget = resolved_widget(link_to: "/reports", view_variant: nil)

    assert_equal "rendered recording_studio_admin/shared/widget", view.render_recording_studio_widget(widget)
    assert_equal "recording_studio_admin/shared/widget", view.rendered_partial
    assert_equal "/reports", view.rendered_locals.fetch(:presenter).href

    assert_equal "rendered recording_studio_admin/shared/widgets/chart",
                 view.render_recording_studio_chart_widget(widget)
    assert_equal "recording_studio_admin/shared/widgets/chart", view.rendered_partial

    assert_equal "rendered recording_studio_admin/shared/widgets/chart",
                 view.render_recording_studio_widget_body(widget)
    assert_equal "recording_studio_admin/shared/widgets/chart", view.rendered_partial
  end

  def test_helper_builds_async_widget_frame_src_from_current_query
    view = FakeWidgetView.new
    widget = resolved_widget(key: "widgets.users.total")

    assert_equal "/admin/sections/users/widgets/widgets.users.total?anchor_url=%2Froot&widget_view_variant=compact",
                 view.recording_studio_widget_frame_src(parent: :section, parent_key: "users", widget: widget)
    assert_equal ["users", "widgets.users.total", { "anchor_url" => "/root", widget_view_variant: :compact }],
                 view.section_widget_path_args
  end

  def test_helper_builds_screen_async_frame_src_with_separate_usage_and_render_variants
    view = FakeWidgetView.new
    widget = resolved_widget(
      key: "widgets.users.total",
      metadata: { recording_studio_admin_widget_usage_index: 0 }
    )
    expected_src = "/admin/screens/users/widgets/widgets.users.total?" \
                   "anchor_url=%2Froot&widget_render_variant=compact&" \
                   "widget_usage_index=0&widget_view_variant=__default__"

    assert_equal expected_src, view.recording_studio_widget_frame_src(
      parent: :screen,
      parent_key: "users",
      widget: widget,
      usage_variant: "__default__"
    )
    assert_equal [
      "users",
      "widgets.users.total",
      {
        "anchor_url" => "/root",
        widget_view_variant: "__default__",
        widget_usage_index: 0,
        widget_render_variant: :compact
      }
    ], view.screen_widget_path_args
  end

  def test_helper_uses_usage_index_for_distinct_frame_ids
    view = FakeWidgetView.new
    first = resolved_widget(metadata: { recording_studio_admin_widget_usage_index: 0 })
    second = resolved_widget(metadata: { recording_studio_admin_widget_usage_index: 1 })

    refute_equal(
      view.recording_studio_widget_frame_id(parent: :screen, parent_key: "users", widget: first),
      view.recording_studio_widget_frame_id(parent: :screen, parent_key: "users", widget: second)
    )
  end

  private

  def resolved_widget(**overrides)
    defaults = {
      key: "widgets.activity.total",
      type: :chart,
      title: "Activity",
      subtitle: "Recent activity",
      description: nil,
      info: nil,
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

    RecordingStudioAdmin::Results::ResolvedWidget.new(**defaults, **overrides)
  end

  class FakeWidgetView
    include RecordingStudioAdmin::WidgetRenderingHelper

    attr_reader :rendered_partial, :rendered_locals, :section_widget_path_args, :screen_widget_path_args

    def render(partial:, locals:)
      @rendered_partial = partial
      @rendered_locals = locals
      "rendered #{partial}"
    end

    def request
      Struct.new(:query_parameters).new({ "anchor_url" => "/root", "controller" => "ignored", "action" => "show" })
    end

    def section_widget_path(parent_key, widget_key, query)
      @section_widget_path_args = [parent_key, widget_key, query]
      "/admin/sections/#{parent_key}/widgets/#{widget_key}?#{query.to_query}"
    end

    def screen_widget_path(parent_key, widget_key, query)
      @screen_widget_path_args = [parent_key, widget_key, query]
      "/admin/screens/#{parent_key}/widgets/#{widget_key}?#{query.to_query}"
    end
  end
end
