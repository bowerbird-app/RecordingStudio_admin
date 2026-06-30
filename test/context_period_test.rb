# frozen_string_literal: true

require "test_helper"

class ContextPeriodTest < Minitest::Test
  def reference_time
    Time.utc(2026, 6, 15, 12, 0, 0)
  end

  def test_period_label_for_duration_supports_days
    context = RecordingStudioAdmin::Context.new

    label = context.period_label(duration: 3.days, reference_time: reference_time)

    assert_equal "Last 3 days", label
  end

  def test_period_label_for_duration_supports_weeks
    context = RecordingStudioAdmin::Context.new

    label = context.period_label(duration: 4.weeks, reference_time: reference_time)

    assert_equal "Last 4 weeks", label
  end

  def test_period_label_uses_filter_preset_for_last_30_days
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 5, 16), Date.new(2026, 6, 15),
                                                                     :last_30_days)
    )

    label = context.period_label(reference_time: reference_time)

    assert_equal "Last 30 days", label
  end

  def test_period_label_derives_weeks_from_filter_window
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 5, 19), Date.new(2026, 6, 15), nil)
    )

    label = context.period_label(reference_time: reference_time)

    assert_equal "Last 4 weeks", label
  end

  def test_period_label_uses_today_name_when_date_range_matches_today
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 6, 15), Date.new(2026, 6, 15), nil)
    )

    label = context.period_label(reference_time: reference_time)

    assert_equal "Today", label
  end

  def test_period_label_uses_last_week_name_when_date_range_matches_last_week
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 6, 8), Date.new(2026, 6, 14), nil)
    )

    label = context.period_label(reference_time: reference_time)

    assert_equal "Last week", label
  end

  def test_period_label_prefers_this_week_for_week_to_date_overlap_with_last_three_days
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 6, 15), Date.new(2026, 6, 17), nil)
    )

    label = context.period_label(reference_time: Time.utc(2026, 6, 17, 12, 0, 0))

    assert_equal "This week", label
  end

  def test_widget_period_label_uses_widget_duration_override
    context = RecordingStudioAdmin::Context.new.with_widget_params(duration: 24.hours)

    label = context.widget_period_label(reference_time: reference_time)

    assert_equal "Last 24 hours", label
  end

  def test_widget_time_range_uses_widget_duration_override
    context = RecordingStudioAdmin::Context.new.with_widget_params(duration: 24.hours)

    range = context.widget_time_range(reference_time: reference_time)

    assert_equal reference_time - 24.hours, range.begin
    assert_equal reference_time, range.end
  end

  def test_widget_filter_params_include_start_end_and_preset
    context = RecordingStudioAdmin::Context.new

    params = context.widget_filter_params(default_preset_key: :last_7_days, reference_time: reference_time)

    assert_equal "2026-06-08", params[:start_date]
    assert_equal "2026-06-15", params[:end_date]
    assert_equal :last_7_days, params[:date_range_preset]
  end

  def test_widget_time_range_uses_period_dates_when_duration_is_not_provided
    context = RecordingStudioAdmin::Context.new

    range = context.widget_time_range(default_preset_key: :last_7_days, reference_time: reference_time)

    assert_equal Time.utc(2026, 6, 8, 0, 0, 0), range.begin
    assert_equal Time.utc(2026, 6, 15, 23, 59, 59).to_i, range.end.to_i
  end

  def test_widget_time_range_returns_nil_when_no_period_can_be_resolved
    context = RecordingStudioAdmin::Context.new

    assert_nil context.widget_time_range(reference_time: reference_time)
  end

  def test_widget_period_falls_back_to_filter_value
    context = RecordingStudioAdmin::Context.new
    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 6, 10), Date.new(2026, 6, 15), nil)
    )

    period = context.widget_period(reference_time: reference_time)

    assert_equal "Last 6 days", period.label
  end

  def test_admin_action_accessors_delegate_to_resolved_action
    action_definition = Struct.new(:resolved_action) do
      def resolve(_record, _context)
        resolved_action
      end
    end

    resolved_action = Struct.new(:url, :http_method, :confirm, :icon, :text).new(
      "/admin/users/1/edit",
      :patch,
      "Are you sure?",
      "pencil",
      "Edit"
    )
    context = RecordingStudioAdmin::Context.new

    with_singleton_stub(RecordingStudioAdmin, :resolve_resource_action, lambda { |**|
      action_definition.new(resolved_action)
    }) do
      assert_equal "/admin/users/1/edit", context.admin_action_path("users", :edit, Object.new)
      assert_equal :patch, context.admin_action_method("users", :edit, Object.new)
      assert_equal "Are you sure?", context.admin_action_confirm("users", :edit, Object.new)
      assert_equal "pencil", context.admin_action_icon("users", :edit, Object.new)
      assert_equal "Edit", context.admin_action_text("users", :edit, Object.new)
    end
  end

  def test_available_admin_calls_honor_explicit_recording_argument
    context = RecordingStudioAdmin::Context.new
    explicit_recording = Object.new

    with_singleton_stub(RecordingStudioAdmin, :available_sections, lambda { |**kwargs|
      assert_same explicit_recording, kwargs[:recording]
      []
    }) do
      context.available_admin_sections(recording: explicit_recording)
    end

    with_singleton_stub(RecordingStudioAdmin, :available_admin_items, lambda { |**kwargs|
      assert_same explicit_recording, kwargs[:recording]
      []
    }) do
      context.available_admin_items(recording: explicit_recording)
    end

    with_singleton_stub(RecordingStudioAdmin, :available_widgets, lambda { |**kwargs|
      assert_same explicit_recording, kwargs[:recording]
      []
    }) do
      context.available_admin_widgets(recording: explicit_recording)
    end
  end

  def test_access_recordable_returns_recordable_from_access_recording
    recording = Struct.new(:recordable).new(:workspace)
    controller = Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
    end.new
    context = RecordingStudioAdmin::Context.new(controller: controller)

    assert_equal :workspace, context.access_recordable
  end

  def test_root_recording_prefers_nested_root_recording
    nested_root = Object.new
    recording = Struct.new(:root_recording).new(nested_root)
    controller = Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
    end.new
    context = RecordingStudioAdmin::Context.new(controller: controller)

    assert_same nested_root, context.root_recording
  end

  def test_root_recording_falls_back_to_recording_studio_helper
    recording = Object.new
    controller = Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
    end.new
    context = RecordingStudioAdmin::Context.new(controller: controller)

    with_singleton_stub(RecordingStudio, :root_recording_or_self, ->(value) { "root-for-#{value.object_id}" }) do
      assert_equal "root-for-#{recording.object_id}", context.root_recording
    end
  end

  def test_private_helpers_cover_callable_arity_filter_range_and_widget_param_validation
    context = RecordingStudioAdmin::Context.new

    assert context.send(:current_time).is_a?(Time)
    assert_equal :zero, context.send(:resolve_callable, -> { :zero })
    assert_same context, context.send(:resolve_callable, ->(value) { value })
    assert_nil context.send(:resolve_callable, ->(_ctx, _controller) {})

    context.set_filter_value(
      :date_range,
      RecordingStudioAdmin::Filters::DateRangeFilter::RangeValue.new(Date.new(2026, 6, 1), Date.new(2026, 6, 2), nil)
    )
    range = context.send(:filter_range, :date_range)
    assert_equal Time.utc(2026, 6, 1, 0, 0, 0), range.begin
    assert_equal Time.utc(2026, 6, 2, 23, 59, 59).to_i, range.end.to_i

    assert_raises(ArgumentError) { context.send(:normalize_widget_params, Object.new) }
  end

  def test_current_time_uses_time_zone_when_present
    context = RecordingStudioAdmin::Context.new

    Time.use_zone("UTC") do
      assert_kind_of ActiveSupport::TimeWithZone, context.send(:current_time)
    end
  end
end
