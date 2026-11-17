# frozen_string_literal: true

require "test_helper"

class FilterFieldsRenderTest < ActionDispatch::IntegrationTest
  VALUES = ["", "queued_root"].freeze

  test "filter fields render blank_label humanize_options and an explicit placeholder" do
    default_options = enabled_select_options(render_filter_fields(values: VALUES))
    labeled_filter = filter_definition(
      values: VALUES,
      blank_label: "All roots",
      humanize_options: false
    )
    labeled_html = render_filter_fields(filter: labeled_filter)
    labeled_options = enabled_select_options(labeled_html)
    placeholder_html = render_filter_fields(
      filter: filter_definition(
        values: VALUES,
        blank_label: "All roots",
        placeholder: "Pick a type",
        humanize_options: false
      )
    )

    assert_equal [{ label: "", value: "" }, { label: "Queued root", value: "queued_root" }], default_options
    assert_equal [{ label: "All roots", value: "" }, { label: "queued_root", value: "queued_root" }], labeled_options
    assert_equal "All roots", labeled_filter.options[:blank_label]
    assert_equal false, labeled_filter.options[:humanize_options]
    assert_equal "All roots", disabled_placeholder_text(labeled_html)
    assert_equal "Pick a type", disabled_placeholder_text(placeholder_html)
  end

  test "select filter renders the default selected when the param is absent" do
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      options: %w[open closed],
      default: :open
    )
    value = definition.normalize({})
    html = render_filter_fields(filter: filter_definition(values: %w[open closed], value: value))
    blank_html = render_filter_fields(
      filter: filter_definition(values: %w[open closed], value: definition.normalize(status: ""))
    )
    selected = selected_option(html)

    assert_equal "open", value
    assert_equal "open", selected["value"]
    assert_equal "Open", selected.text
    assert_nil selected_option(blank_html)
    assert_equal "All", disabled_placeholder_text(blank_html)
  end

  private

  def filter_definition(values:, value: nil, **options)
    RecordingStudioAdmin::Results::ResolvedFilter.new(
      :root_type,
      :select,
      value,
      options.merge(values: values),
      :root_type,
      nil,
      nil,
      nil
    )
  end

  def render_filter_fields(filter: nil, values: VALUES, **options)
    RecordingStudioAdmin::ApplicationController.renderer.render(
      partial: "recording_studio_admin/screens/filter_fields",
      locals: {
        filters: [filter || filter_definition(values: values, **options)],
        wrapper_class: ""
      }
    )
  end

  def enabled_select_options(html)
    Nokogiri::HTML5.fragment(html).css("option:not([disabled])").map do |option|
      { label: option.text, value: option["value"].to_s }
    end
  end

  def disabled_placeholder_text(html)
    Nokogiri::HTML5.fragment(html).at_css("option[disabled]")&.text
  end

  def selected_option(html)
    Nokogiri::HTML5.fragment(html).at_css("option[selected]:not([disabled])")
  end
end
