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

  private

  def filter_definition(values:, **options)
    RecordingStudioAdmin::Results::ResolvedFilter.new(
      :root_type,
      :select,
      nil,
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
end
