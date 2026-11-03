# frozen_string_literal: true

require "test_helper"

class ScreenFiltersDateRangeApplyTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_date_range_filters_use_one_auto_submit_path_and_flatpack_preset_name
    filter_fields = File.read(File.join(ROOT, "app/views/recording_studio_admin/screens/_filter_fields.html.erb"))
    filters = File.read(File.join(ROOT, "app/views/recording_studio_admin/screens/_filters.html.erb"))
    controller = File.read(
      File.join(ROOT, "app/javascript/recording_studio_admin/controllers/screen_filters_controller.js")
    )

    assert_includes filter_fields, "preset_name: filter.preset_param.to_s"
    assert_includes filter_fields, 't("recording_studio.admin.screens.filters.date_presets.#{key}"'
    refute_includes filter_fields, "hidden_field_tag filter.preset_param"
    assert_equal 1, filters.scan("change->flat-pack--auto-submit#queueSubmit").size
    refute_includes filters, "queueDateRangeSubmit"
    refute_includes filters, "date-preset-labels-value"
    refute_includes controller, "queueDateRangeSubmit"
    refute_includes controller, "data-flat-pack-date-picker-command"
    refute_includes controller, "syncPresetLabelsFromHiddenFields"
  end
end
