# frozen_string_literal: true

require "test_helper"

class ResolverTest < Minitest::Test
  Row = Struct.new(:created_at, :status, :name)
  TestRecording = Struct.new(:parent_recording)
  TestRecordingWithRecordable = Struct.new(:recordable, :parent_recording)

  class ArrayRelation
    attr_reader :rows, :orders

    def initialize(rows)
      @rows = rows
      @orders = []
    end

    def count = rows.count
    def to_a = rows
    def limit(value) = self.class.new(rows.first(value))
    def offset(value) = self.class.new(rows.drop(value))

    def where(conditions)
      conditions.reduce(self) do |relation, (field, expected)|
        self.class.new(relation.rows.select { |row| matches_condition?(row.public_send(field), expected) })
      end
    end

    def order(order_hash)
      ordered = rows.sort_by { |row| row.public_send(order_hash.keys.first) }
      ordered.reverse! if order_hash.values.first.to_s == "desc"
      self.class.new(ordered)
    end

    private

    def matches_condition?(actual, expected)
      return expected.cover?(actual) if expected.is_a?(Range)

      actual == expected
    end
  end

  class RequestsScreen < RecordingStudioAdmin::Screen
    key "requests"
    icon :document_text
    title "Requests"
    subtitle "Traffic"
    availability_scope :root
    query do |_context|
      ArrayRelation.new([
                          Row.new(Time.now - 1.day, 200, "b"),
                          Row.new(Time.now - 2.days, 500, "a"),
                          Row.new(Time.now - 40.days, 200, "previous")
                        ])
    end
    filter :date_range, field: :created_at, default: :last_30_days
    filter :group_by, default: :day
    filter :state, options: -> { %w[open closed] }

    summary do
      label "Total requests"
    end

    chart do
      title "Traffic"
      type :line
      series { [] }
    end

    table do
      filter :search, apply: lambda { |relation, value, _context|
        next relation unless value.present?

        ArrayRelation.new(relation.rows.select { |row| row.name.include?(value) })
      }
      column :created_at
      column :name
      column(
        :status,
        display: :badge,
        display_options: lambda { |_row, _context, value|
          { text: value.to_s, style: value.to_i >= 500 ? :danger : :success, size: :sm }
        }
      )
      default_columns :name, :status
      action :unsafe,
             text: ->(row, _context) { "Review #{row.name}" },
             icon: "eye",
             url: ->(_row, _context) { "javascript:alert(1)" },
             method: :delete,
             confirm: ->(row, _context) { "Delete #{row.name}?" }
      paginate per_page: 1
    end

    widget :total do
      title "Total"
      description "Total requests returned by the current query."
      value { |context| context.query_result.count }
      link_to { |context| context.admin_screen_path("requests") }
    end

    widget :recent_statuses do
      type :list
      title "Recent statuses"
      list_options divider: true, spacing: :dense, hover: true
      items do |context|
        [
          {
            text: "200 OK",
            icon: :check,
            trailing: "Healthy",
            href: context.admin_screen_path("requests")
          },
          {
            label: "500 Error",
            leading: "!",
            href: "javascript:alert(1)"
          }
        ]
      end
    end

    widget :traffic_preview do
      type :chart
      title "Traffic preview"
      link_label "Traffic details"
      chart_type :bar
      metadata { |context| { period_label: context.widget_period_label(default_duration: 7.days) } }
      value { |context| context.widget_param(:limit, default: 2) }
      series do |context|
        [{
          name: context.widget_group_by(default: :day).to_s,
          data: [{ x: context.widget_period_label(default_duration: 7.days),
                   y: context.widget_param(:limit, default: 2) }]
        }]
      end
    end

    widget :review_completion do
      type :progress
      title "Review completion"
      subtitle "Resolved review backlog"
      metadata do |context|
        reviewed = context.widget_param(:reviewed, default: 3)
        total = context.widget_param(:total, default: 5)

        {
          period_label: context.widget_period_label(default_duration: 7.days),
          progress_value: reviewed,
          progress_max: total,
          progress_label: "#{reviewed} / #{total}"
        }
      end
    end

    widget :churn do
      type :number
      title "Churn"
      value 7
      change "+30%"
      change_good_when :down
    end

    widget :alias_polarity do
      type :number
      title "Alias"
      value 1
      change "-2%"
      change_good_when :negative
    end

    widget :hidden_summary_parts do
      type :number
      title "Hidden summary parts"
      value 9
      change "+4%"
      metadata period_label: "Last 7 days"
      hide_metric
      hide_change
      hide_period
    end

    widget :legacy_total do
      type :stat
      title "Legacy total"
      value { |context| context.query_result.count }
    end
  end

  class HiddenSummaryScreen < RecordingStudioAdmin::Screen
    key "hidden_summary"
    query { |_context| ArrayRelation.new([Row.new(Time.now - 1.day, 200, "a")]) }
    filter :date_range, field: :created_at, default: :last_30_days

    summary do
      hide_metric
      hide_change
      hide_period
    end
  end

  class HiddenScreen < RecordingStudioAdmin::Screen
    key "hidden"
    visible_if ->(_context) { false }
    query { |_context| ArrayRelation.new([]) }
  end

  class MetadataOnlyScreen < RecordingStudioAdmin::Screen
    key "metadata_only"
    title "Metadata only"
    subtitle "Should not execute queries"
    icon :magnifying_glass
    availability_scope :root
    query { |_context| flunk "search metadata helper should not resolve screen queries" }
  end

  class ChildScreen < RecordingStudioAdmin::Screen
    key "child_screen"
    title "Child screen"
    subtitle "Descendant screen"
    icon :user_circle
    availability_scope :descendant
    query { |_context| ArrayRelation.new([]) }
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    icon :folder
    title "Root"
    link :requests, text: "Requests", url: ->(context) { context.admin_screen_path("requests") }, style: :primary
    widget "requests.widgets.total", view_variant: :compact
    widget "requests.widgets.traffic_preview",
           title: "Weekly traffic",
           chart_type: :area,
           chart_options: { colors: ["#123456"] },
           params: { duration: 3.days, group_by: :week, limit: 5 }
  end

  class HiddenSection < RecordingStudioAdmin::Section
    key "hidden"
    visible_if ->(_context) { false }
    title "Hidden"
  end

  class ChildSection < RecordingStudioAdmin::Section
    key "child"
    title "Child"
    availability_scope :descendant
  end

  class EverywhereSection < RecordingStudioAdmin::Section
    key "everywhere"
    title "Everywhere"
    availability_scope :all
  end

  class AdminSectionEnabledRecordable
    include RecordingStudioAdmin::AllowsAdminSections

    recording_studio_admin_sections do
      section :root
      section :missing
      section :hidden
    end
  end

  class AlternateAdminSectionRecordable
    include RecordingStudioAdmin::AllowsAdminSections

    recording_studio_admin_sections do
      section :everywhere
    end
  end

  FakeRecordable = Struct.new(:attributes) do
    def self.find_or_create_by!(attributes)
      new(attributes)
    end
  end

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    @original_admin_sections_resolver = RecordingStudioAdmin.configuration.admin_sections_resolver
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.configuration.admin_sections_resolver = nil
    RecordingStudioAdmin.register_screen(RequestsScreen)
    RecordingStudioAdmin.register_screen(HiddenScreen)
    RecordingStudioAdmin.register_screen(HiddenSummaryScreen)
    RecordingStudioAdmin.register_screen(MetadataOnlyScreen)
    RecordingStudioAdmin.register_screen(ChildScreen)
    RecordingStudioAdmin.register_section(RootSection)
    RecordingStudioAdmin.register_section(HiddenSection)
    RecordingStudioAdmin.register_section(ChildSection)
    RecordingStudioAdmin.register_section(EverywhereSection)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
    RecordingStudioAdmin.configuration.admin_sections_resolver = @original_admin_sections_resolver
    RecordingStudioAdmin.configuration.surfaces.clear
  end

  def allowed_context(params: {}, recording: nil, current_root_recording: nil)
    RecordingStudioAdmin::Context.new(
      params: params,
      current_actor: :actor,
      controller: allowed_context_controller(recording: recording, current_root_recording: current_root_recording)
    )
  end

  def allowed_context_controller(recording: nil, current_root_recording: nil)
    recording ||= Object.new
    Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
      define_method(:current_root_recording) { current_root_recording } unless current_root_recording.nil?
    end.new
  end

  def test_context_access_recording_prefers_configured_resolver
    original_resolver = RecordingStudioAdmin.configuration.access_recording_resolver
    expected_recording = Object.new
    controller_recording = Object.new
    controller = Class.new do
      define_method(:recording_studio_admin_access_recording) { controller_recording }
    end.new
    RecordingStudioAdmin.configuration.access_recording_resolver = lambda { |context|
      expected_recording if context.controller.equal?(controller)
    }

    context = RecordingStudioAdmin::Context.new(controller: controller)

    assert_equal expected_recording, context.access_recording
  ensure
    RecordingStudioAdmin.configuration.access_recording_resolver = original_resolver
  end

  def test_context_access_recording_prefers_surface_resolver
    original_resolver = RecordingStudioAdmin.configuration.access_recording_resolver
    global_recording = Object.new
    surface_recording = Object.new
    RecordingStudioAdmin.configuration.access_recording_resolver = ->(_context) { global_recording }
    surface = RecordingStudioAdmin.configuration.surface(:stats, path: "/stats") do |configured_surface|
      configured_surface.access_recording_resolver = ->(_context) { surface_recording }
    end

    context = RecordingStudioAdmin::Context.new(surface: surface)

    assert_equal surface_recording, context.access_recording
  ensure
    RecordingStudioAdmin.configuration.access_recording_resolver = original_resolver
  end

  def test_section_resolver_rejects_non_hash_widget_usage_values
    context = allowed_context
    resolver = RecordingStudioAdmin::Resolvers::SectionResolver.new("root", context)

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      resolver.resolve_usage_hash(RootSection, "invalid", context, field_name: :params)
    end

    assert_includes error.message, "must resolve to a Hash"
  end

  def test_context_paths_fall_back_to_surface_path
    surface = RecordingStudioAdmin.configuration.surface(:stats, path: "/stats")
    context = RecordingStudioAdmin::Context.new(routes: Object.new, surface: surface)

    assert_equal "/stats/sections/page_views", context.admin_section_path("page_views")
    assert_equal "/stats/screens/page_views", context.admin_screen_path("page_views")
    assert_equal "/stats/sections", context.admin_sections_path
  end

  def test_screen_resolution_fails_closed_without_access_recording
    assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      RecordingStudioAdmin.resolve_screen(key: "requests", context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_screen_resolution_fails_closed_without_current_actor
    context = RecordingStudioAdmin::Context.new(controller: allowed_context_controller)

    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, ->(**) { flunk "access check should not run" }) do
        RecordingStudioAdmin.resolve_screen(key: "requests", context: context)
      end
    end

    assert_includes error.message, "current actor is not configured"
  end

  def test_screen_resolution_fails_closed_when_access_is_denied
    context = allowed_context

    with_singleton_stub(RecordingStudioAccessible, :authorized?, false) do
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.resolve_screen(key: "requests", context: context)
      end
    end
  end

  def test_screen_resolution_fails_closed_when_current_root_does_not_match_access_root
    access_root_recording = Struct.new(:root_recording).new(nil)
    current_root_recording = Object.new
    context = allowed_context(recording: access_root_recording, current_root_recording: current_root_recording)

    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, ->(**) { flunk "access check should not run" }) do
        RecordingStudioAdmin.resolve_screen(key: "requests", context: context)
      end
    end

    assert_includes error.message, "Current root does not match"
  end

  def test_available_sections_authorizes_explicit_recording
    context_recording = Object.new
    explicit_recording = Object.new
    context = allowed_context(recording: context_recording)
    authorized_recordings = []
    authorizer = lambda do |actor:, recording:, role:|
      assert_equal :actor, actor
      assert_equal :view, role
      authorized_recordings << recording
      recording.equal?(context_recording)
    end

    with_singleton_stub(RecordingStudioAccessible, :authorized?, authorizer) do
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.available_sections(context: context, recording: explicit_recording, placement: :root)
      end
    end

    assert_equal [explicit_recording], authorized_recordings
  end

  def with_access_allowed(&)
    with_singleton_stub(RecordingStudioAccessible, :authorized?, true, &)
  end

  def test_resolve_screen_returns_structured_result_without_html
    context = allowed_context(params: { sort: "name", direction: "asc" })

    result = with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "requests", context: context) }

    assert_equal "Requests", result.title
    assert_equal 2, result.query_result.count
    assert_equal 1, result.table.rows.size
    assert_equal "name", result.table.result.sort
    assert_equal :infinite, result.table.result.mode
    assert_equal %i[name status], result.table.columns.map(&:key)
    assert_equal %i[created_at name status], result.table.available_columns.map(&:key)
    assert_equal %w[name status], result.table.selected_column_keys
    assert_equal :day, context.filter_value(:group_by)
    assert_equal 2, result.widgets.first.value
    assert_equal :number, result.widgets.first.type
    assert_equal "Total requests", result.summary.label
    assert_equal 2, result.summary.value
    assert_equal "+100%", result.summary.change
    assert_equal :up, result.summary.change_good_when
    assert_equal "Last 30 days", result.summary.period_label
    assert result.summary.show_metric
    assert result.summary.show_change
    assert result.summary.show_period

    recent_statuses = result.widgets.find { |widget| widget.key == "requests.widgets.recent_statuses" }
    assert_equal :list, recent_statuses.type
    assert_equal({ divider: true, spacing: :dense, hover: true }, recent_statuses.list_options)
    assert_equal "200 OK", recent_statuses.items.first[:text]
    assert_equal :check, recent_statuses.items.first[:icon]
    assert_equal "Healthy", recent_statuses.items.first[:trailing]
    assert_equal "/admin/screens/requests", recent_statuses.items.first[:href]
    assert_equal "500 Error", recent_statuses.items.second[:label]
    assert_equal "#", recent_statuses.items.second[:href]
    traffic_preview = result.widgets.find { |widget| widget.key == "requests.widgets.traffic_preview" }
    assert_equal :chart, traffic_preview.type
    assert_equal "Traffic details", traffic_preview.link_label
    assert_equal :bar, traffic_preview.chart_type
    assert_equal [{ name: "day", data: [{ x: "Last 7 days", y: 2 }] }], traffic_preview.series
    assert_equal "Last 7 days", traffic_preview.metadata[:period_label]
    assert_equal 2, traffic_preview.value
    resolved_action = result.table.actions.first.resolve(result.table.rows.first, context)
    assert_equal "Review a", resolved_action.text
    assert_equal "#", resolved_action.url
    assert_equal "eye", resolved_action.icon
    assert_equal :delete, resolved_action.method
    assert_equal "Delete a?", resolved_action.confirm
    assert resolved_action.destructive
    status_column = result.table.columns.find { |column| column.key == :status }
    assert_equal :badge, status_column.display
    assert_equal(
      { text: "500", style: :danger, size: :sm },
      status_column.display_options_for(result.table.rows.first, context, 500)
    )
  end

  def test_screen_summary_visibility_can_hide_metric_change_and_period
    result = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "hidden_summary", context: allowed_context)
    end

    refute result.summary.show_metric
    refute result.summary.show_change
    refute result.summary.show_period
  end

  def test_table_filter_definitions_are_applied_to_the_whole_screen_relation
    context = allowed_context(params: { search: "a" })

    result = with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "requests", context: context) }

    assert_equal "a", context.filter_value(:search)
    assert_equal(%w[date_range group_by state search], result.filters.map { |filter| filter.param_key.to_s })
    assert_equal 1, result.query_result.count
    assert_equal 1, result.table.result.total_count
    assert_equal ["a"], result.table.rows.map(&:name)
  end

  def test_table_uses_default_columns_until_request_overrides_them
    result = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "requests", context: allowed_context)
    end

    assert_equal %i[name status], result.table.columns.map(&:key)
  end

  def test_table_column_selection_allows_only_declared_columns
    context = allowed_context(params: { columns: %w[status created_at unknown] })

    result = with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "requests", context: context) }

    assert_equal %i[created_at status], result.table.columns.map(&:key)
    assert_equal %w[status created_at], result.table.selected_column_keys
  end

  def test_table_column_selection_keeps_at_least_one_visible_column
    context = allowed_context(params: { columns_present: "1" })

    result = with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "requests", context: context) }

    assert_equal %i[name status], result.table.columns.map(&:key)
    assert_equal %w[name status], result.table.selected_column_keys
  end

  def test_table_sort_falls_back_when_requested_column_is_not_visible
    context = allowed_context(params: { sort: "created_at" })

    result = with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "requests", context: context) }

    assert_equal "name", result.table.result.sort
  end

  def test_table_pagination_defaults_to_infinite_scroll
    table = RecordingStudioAdmin::TableDefinition.new do
      column :name
    end

    assert_equal({ per_page: 50, mode: :infinite }, table.pagination_options)
  end

  def test_legacy_stat_widgets_are_normalized_to_number
    widget = with_access_allowed do
      RecordingStudioAdmin.resolve_widget(key: "requests.widgets.legacy_total", context: allowed_context)
    end

    assert_equal :number, widget.type
    assert_equal 2, widget.value
    assert_equal :up, widget.change_good_when
  end

  def test_widget_description_is_resolved
    widget = with_access_allowed do
      RecordingStudioAdmin.resolve_widget(key: "requests.widgets.total", context: allowed_context)
    end

    assert_equal "Total requests returned by the current query.", widget.description
    assert_equal "Requests", widget.link_label
  end

  def test_widget_change_good_when_is_resolved
    widget = with_access_allowed do
      RecordingStudioAdmin.resolve_widget(key: "requests.widgets.churn", context: allowed_context)
    end

    assert_equal :down, widget.change_good_when
    assert_equal "+30%", widget.change
  end

  def test_widget_change_good_when_aliases_are_normalized
    widget = with_access_allowed do
      RecordingStudioAdmin.resolve_widget(key: "requests.widgets.alias_polarity", context: allowed_context)
    end

    assert_equal :down, widget.change_good_when
  end

  def test_widget_summary_visibility_flags_are_resolved
    widget = with_access_allowed do
      RecordingStudioAdmin.resolve_widget(key: "requests.widgets.hidden_summary_parts", context: allowed_context)
    end

    refute widget.show_metric
    refute widget.show_change
    refute widget.show_period
  end

  def test_standalone_widget_resolution_fails_authorization_before_resolving
    widget = RecordingStudioAdmin::Widget.new("standalone_health") do
      title "Standalone health"
      value { |_context| raise "standalone widget should not resolve" }
    end
    RecordingStudioAdmin.register_widget(widget)

    with_singleton_stub(RecordingStudioAccessible, :authorized?, false) do
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.resolve_widget(key: widget.key, context: allowed_context)
      end
    end
  end

  def test_standalone_widget_resolution_succeeds_after_authorization
    widget = RecordingStudioAdmin::Widget.new("standalone_health") do
      title "Standalone health"
      value 1
    end
    RecordingStudioAdmin.register_widget(widget)

    resolved = with_access_allowed do
      RecordingStudioAdmin.resolve_widget(key: widget.key, context: allowed_context)
    end

    assert_equal "widgets.standalone_health", resolved.key
    assert_equal 1, resolved.value
  end

  def test_invalid_widget_types_raise_specific_error
    widget = RecordingStudioAdmin::Widget.new("broken") do
      type :unknown
      value 1
    end

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      widget.resolve(RecordingStudioAdmin::Context.new)
    end

    assert_includes error.message, "unsupported type"
  end

  def test_invalid_change_good_when_raises_specific_error
    widget = RecordingStudioAdmin::Widget.new("bad-polarity") do
      type :number
      value 1
      change_good_when :sideways
    end

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      widget.resolve(RecordingStudioAdmin::Context.new)
    end

    assert_includes error.message, "unsupported change_good_when"
  end

  def test_list_widget_rejects_unknown_list_options
    widget = RecordingStudioAdmin::Widget.new("bad-list-options") do
      type :list
      items ["one"]
      list_options divider: true, unsupported: :value
    end

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      widget.resolve(RecordingStudioAdmin::Context.new)
    end

    assert_includes error.message, "unsupported list_options keys"
  end

  def test_list_widget_allows_hover_list_option
    widget = RecordingStudioAdmin::Widget.new("hover-list-options") do
      type :list
      items ["one"]
      list_options divider: true, hover: true
    end

    resolved = widget.resolve(RecordingStudioAdmin::Context.new)

    assert_equal({ divider: true, hover: true }, resolved.list_options)
  end

  def test_list_widget_rejects_hash_items_without_text_or_label
    widget = RecordingStudioAdmin::Widget.new("bad-list-item") do
      type :list
      items [{ icon: :check }]
    end

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      widget.resolve(RecordingStudioAdmin::Context.new)
    end

    assert_includes error.message, "require :text or :label"
  end

  def test_progress_widget_uses_metadata_payload
    widget = with_access_allowed do
      RecordingStudioAdmin.resolve_widget(key: "requests.widgets.review_completion", context: allowed_context)
    end

    assert_equal :progress, widget.type
    assert_equal "Resolved review backlog", widget.subtitle
    assert_equal "Last 7 days", widget.metadata[:period_label]
    assert_equal 3, widget.metadata[:progress_value]
    assert_equal 5, widget.metadata[:progress_max]
    assert_equal "3 / 5", widget.metadata[:progress_label]
    assert_nil widget.metadata[:progress_variant]
  end

  def test_progress_widget_requires_metadata_progress_value
    widget = RecordingStudioAdmin::Widget.new("missing-progress") do
      type :progress
      metadata progress_label: "0 / 10"
    end

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      widget.resolve(RecordingStudioAdmin::Context.new)
    end

    assert_includes error.message, "metadata[:progress_value]"
  end

  def test_progress_widget_rejects_progress_values_above_max
    widget = RecordingStudioAdmin::Widget.new("overflow-progress") do
      type :progress
      metadata progress_value: 12, progress_max: 10
    end

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      widget.resolve(RecordingStudioAdmin::Context.new)
    end

    assert_includes error.message, "less than or equal to progress_max"
  end

  def test_proc_backed_filter_options_are_resolved
    result = with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "requests", context: allowed_context) }

    assert_equal %w[open closed], result.filters.find { |filter| filter.key == :state }.options[:values]
  end

  def test_context_fallback_paths_use_configured_default_mount_path
    original_mount_path = RecordingStudioAdmin.configuration.default_mount_path
    RecordingStudioAdmin.configuration.default_mount_path = "/backoffice"

    context = RecordingStudioAdmin::Context.new

    assert_equal "/backoffice/screens/requests", context.admin_screen_path("requests")
    assert_equal "/backoffice/sections", context.admin_sections_path
    assert_equal "/backoffice/sections/root", context.admin_section_path("root")
  ensure
    RecordingStudioAdmin.configuration.default_mount_path = original_mount_path
  end

  def test_missing_screen_raises_specific_error
    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      RecordingStudioAdmin.resolve_screen(key: "missing", context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_hidden_screen_and_section_fail_authorization_before_visibility_without_access_recording
    assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      RecordingStudioAdmin.resolve_screen(key: "hidden", context: RecordingStudioAdmin::Context.new)
    end

    assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      RecordingStudioAdmin.resolve_section(key: "hidden", context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_hidden_screen_and_section_raise_not_found_after_authorization
    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "hidden", context: allowed_context) }
    end

    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      with_access_allowed { RecordingStudioAdmin.resolve_section(key: "hidden", context: allowed_context) }
    end
  end

  def test_resolve_sections_requires_authorization
    assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      RecordingStudioAdmin.resolve_sections(context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_resolve_sections_returns_only_visible_sections
    sections = with_access_allowed { RecordingStudioAdmin.resolve_sections(context: allowed_context) }

    assert_equal %w[child everywhere root], sections.map(&:key)
    root_section = sections.find { |section| section.key == "root" }
    assert_equal "Root", root_section.title
    assert_equal :folder, root_section.icon
    assert_equal "/admin/sections/root", root_section.url
  end

  def test_available_sections_returns_all_visible_sections_by_default
    sections = with_access_allowed { RecordingStudioAdmin.available_sections(context: allowed_context) }

    assert_equal %w[child everywhere root], sections.map(&:key)
    assert_equal :descendant, sections.first.availability_scope
  end

  def test_available_admin_items_requires_authorization
    assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      RecordingStudioAdmin.available_admin_items(context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_available_admin_items_returns_sections_and_screens_without_resolving_queries
    items = with_access_allowed do
      RecordingStudioAdmin.available_admin_items(context: allowed_context(recording: TestRecording.new(nil)),
                                                 placement: :root)
    end

    assert_equal %w[everywhere metadata_only requests root], items.map(&:key)
    assert_equal %i[section screen screen section], items.map(&:type)
    requests = items.find { |item| item.key == "requests" }
    assert_equal :document_text, requests.icon
    assert_equal "/admin/screens/requests", requests.url
    assert_nil requests.parent_key
    assert_equal :root, requests.availability_scope
    assert_includes requests.search_text, "requests"
    metadata_only = items.find { |item| item.key == "metadata_only" }
    assert_equal "Metadata only", metadata_only.title
  end

  def test_available_admin_items_can_include_only_sections_or_screens
    root_context = allowed_context(recording: TestRecording.new(nil))

    sections = with_access_allowed do
      RecordingStudioAdmin.available_admin_items(context: root_context, placement: :root, include: :sections)
    end
    screens = with_access_allowed do
      RecordingStudioAdmin.available_admin_items(context: root_context, placement: :root, include: :screens)
    end

    assert_equal %i[section section], sections.map(&:type)
    assert_equal %w[everywhere root], sections.map(&:key)
    assert_equal %i[screen screen], screens.map(&:type)
    assert_equal %w[metadata_only requests], screens.map(&:key)
  end

  def test_enabled_admin_items_can_be_scoped_to_section_links
    recording = TestRecordingWithRecordable.new(AdminSectionEnabledRecordable.new, nil)

    items = with_access_allowed do
      RecordingStudioAdmin.available_admin_items(
        context: allowed_context(recording: recording),
        recording: recording,
        parent: :root
      )
    end

    assert_equal ["requests"], items.map(&:key)
    assert_equal ["root"], items.map(&:parent_key)
  end

  def test_context_available_admin_items_uses_context_access_recording
    root_recording = TestRecording.new(nil)
    context = allowed_context(recording: root_recording)

    items = with_access_allowed { context.available_admin_items(placement: :root) }

    assert_equal %w[everywhere metadata_only requests root], items.map(&:key)
  end

  def test_available_sections_filters_root_scoped_sections_for_root_recording
    root_recording = TestRecording.new(nil)

    sections = with_access_allowed do
      RecordingStudioAdmin.available_sections(
        context: allowed_context(recording: root_recording),
        placement: :root
      )
    end

    assert_equal %w[everywhere root], sections.map(&:key)
  end

  def test_available_sections_filters_descendant_scoped_sections_for_child_recording
    root_recording = TestRecording.new(nil)
    child_recording = TestRecording.new(root_recording)

    sections = with_access_allowed do
      RecordingStudioAdmin.available_sections(
        context: allowed_context(recording: child_recording),
        placement: :descendant
      )
    end

    assert_equal %w[child everywhere], sections.map(&:key)
  end

  def test_context_available_admin_sections_uses_context_access_recording
    root_recording = TestRecording.new(nil)
    context = allowed_context(recording: root_recording)

    sections = with_access_allowed { context.available_admin_sections(placement: :root) }

    assert_equal %w[everywhere root], sections.map(&:key)
  end

  def test_available_sections_prefers_recordable_enabled_admin_sections
    recording = TestRecordingWithRecordable.new(AdminSectionEnabledRecordable.new, nil)

    sections = with_access_allowed do
      RecordingStudioAdmin.available_sections(context: allowed_context(recording: recording), recording: recording)
    end

    assert_equal ["root"], sections.map(&:key)
  end

  def test_same_section_can_be_enabled_on_different_recordable_types
    first_recording = TestRecordingWithRecordable.new(AdminSectionEnabledRecordable.new, nil)
    second_recording = TestRecordingWithRecordable.new(AlternateAdminSectionRecordable.new, nil)

    first_sections = with_access_allowed do
      RecordingStudioAdmin.available_sections(
        context: allowed_context(recording: first_recording),
        recording: first_recording
      )
    end
    second_sections = with_access_allowed do
      RecordingStudioAdmin.available_sections(
        context: allowed_context(recording: second_recording),
        recording: second_recording
      )
    end

    assert_equal ["root"], first_sections.map(&:key)
    assert_equal ["everywhere"], second_sections.map(&:key)
  end

  def test_available_admin_items_searches_enabled_sections_and_links_only
    recording = TestRecordingWithRecordable.new(AdminSectionEnabledRecordable.new, nil)

    items = with_access_allowed do
      RecordingStudioAdmin.available_admin_items(context: allowed_context(recording: recording), recording: recording)
    end

    assert_equal %w[requests root], items.map(&:key)
    assert_equal %i[screen section], items.map(&:type)
    refute_includes items.map(&:key), "metadata_only"
  end

  def test_available_widgets_requires_authorization
    assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      RecordingStudioAdmin.available_widgets(context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_available_widgets_returns_section_widget_metadata_without_resolving_widget_data
    root_recording = TestRecording.new(nil)

    widgets = with_access_allowed do
      RecordingStudioAdmin.available_widgets(
        context: allowed_context(recording: root_recording),
        recording: root_recording,
        placement: :root,
        include: :section_widgets
      )
    end

    assert_equal %w[requests.widgets.total requests.widgets.traffic_preview], widgets.map(&:key)
    assert_equal [:section_widget, :section_widget], widgets.map(&:source)
    assert_equal ["root", "root"], widgets.map(&:section_key)
    assert_equal ["requests", "requests"], widgets.map(&:screen_key)
    assert_equal [:compact, nil], widgets.map(&:view_variant)
    assert_equal({}, widgets.first.params)

    traffic_preview = widgets.last
    assert_equal "Weekly traffic", traffic_preview.title
    assert_equal :chart, traffic_preview.type
    assert_equal :area, traffic_preview.chart_type
    assert_equal({ duration: 3.days, group_by: :week, limit: 5 }, traffic_preview.params)
    assert_equal root_recording, traffic_preview.recording
    assert_nil traffic_preview.recordable
    assert_equal "default", traffic_preview.surface_key
  end

  def test_available_widgets_can_include_linked_screen_widgets
    root_recording = TestRecording.new(nil)

    widgets = with_access_allowed do
      RecordingStudioAdmin.available_widgets(
        context: allowed_context(recording: root_recording),
        recording: root_recording,
        placement: :root,
        include: :linked_screen_widgets
      )
    end

    assert_includes widgets.map(&:key), "requests.widgets.total"
    assert_includes widgets.map(&:key), "requests.widgets.recent_statuses"
    assert_equal [:linked_screen_widget], widgets.map(&:source).uniq
    assert_equal ["root"], widgets.map(&:section_key).uniq
  end

  def test_available_widgets_prefers_recordable_enabled_admin_sections
    recording = TestRecordingWithRecordable.new(AdminSectionEnabledRecordable.new, nil)

    widgets = with_access_allowed do
      RecordingStudioAdmin.available_widgets(context: allowed_context(recording: recording), recording: recording)
    end

    assert_includes widgets.map(&:key), "requests.widgets.total"
    assert_equal ["root"], widgets.map(&:section_key).uniq
    refute_includes widgets.map(&:section_key), "everywhere"
  end

  def test_context_available_admin_widgets_uses_context_access_recording
    root_recording = TestRecording.new(nil)
    context = allowed_context(recording: root_recording)

    widgets = with_access_allowed { context.available_admin_widgets(placement: :root, include: :section_widgets) }

    assert_equal %w[requests.widgets.total requests.widgets.traffic_preview], widgets.map(&:key)
    assert_equal [root_recording], widgets.map(&:recording).uniq
  end

  def test_configured_admin_sections_resolver_replaces_recordable_declarations
    recording = TestRecordingWithRecordable.new(AdminSectionEnabledRecordable.new, nil)
    RecordingStudioAdmin.configuration.admin_sections_resolver = lambda do |recording:, recordable:, context:|
      assert_equal recording.recordable, recordable
      assert_kind_of RecordingStudioAdmin::Context, context

      [:everywhere]
    end

    sections = with_access_allowed do
      RecordingStudioAdmin.available_sections(context: allowed_context(recording: recording), recording: recording)
    end

    assert_equal ["everywhere"], sections.map(&:key)
  end

  def test_available_sections_do_not_resolve_section_recordables
    backed_section = Class.new(RecordingStudioAdmin::Section) do
      key "backed_available"
      title "Backed available"
      availability_scope :root
      recordable FakeRecordable,
                 find_or_create_by: -> { flunk "recordable should not be resolved when listing available sections" },
                 parent: -> { flunk "parent should not be resolved when listing available sections" }
    end

    RecordingStudioAdmin.register_section(backed_section)

    root_recording = TestRecording.new(nil)
    sections = with_access_allowed do
      RecordingStudioAdmin.available_sections(
        context: allowed_context(recording: root_recording),
        placement: :root
      )
    end

    assert_includes sections.map(&:key), "backed_available"
  end

  def test_section_availability_scope_rejects_unknown_values
    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Section) do
        key "bad-availability-scope"
        title "Bad availability scope"
        availability_scope :sideways
      end
    end

    assert_includes error.message, "unsupported value"
  end

  def test_pagination_page_is_capped
    context = allowed_context(params: { page: "999999" })

    result = with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "requests", context: context) }

    assert_equal 1_000, result.table.result.current_page
  end

  def test_resolve_section_links_widgets_and_missing_widget
    context = allowed_context
    section = with_access_allowed { RecordingStudioAdmin.resolve_section(key: "root", context: context) }

    assert_equal "Root", section.title
    assert_equal :folder, section.icon
    assert_equal "/admin/screens/requests", section.links.first.url
    assert_equal "requests.widgets.total", section.widgets.first.key
    assert_equal :compact, section.widgets.first.view_variant
    traffic_preview = section.widgets.find { |widget| widget.key == "requests.widgets.traffic_preview" }
    assert_equal "Weekly traffic", traffic_preview.title
    assert_equal :area, traffic_preview.chart_type
    assert_equal ["#123456"], traffic_preview.chart_options[:colors]
    assert_equal [{ name: "week", data: [{ x: "Last 3 days", y: 5 }] }], traffic_preview.series
    assert_equal "Last 3 days", traffic_preview.metadata[:period_label]
    assert_equal 5, traffic_preview.value
    assert_nil section.recordable
    assert_nil section.recording
  end

  def test_section_widget_chart_options_reject_non_hash_values
    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Section) do
        key "bad-chart-options"
        title "Bad"
        widget "requests.widgets.total", chart_options: :blue
      end
    end

    assert_includes error.message, "chart_options must be a Hash"
  end

  def test_section_widget_params_reject_non_hash_values
    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Section) do
        key "bad-widget-params"
        title "Bad"
        widget "requests.widgets.total", params: :recent
      end
    end

    assert_includes error.message, "params must be a Hash"
  end

  def test_section_widget_view_variant_rejects_unknown_values
    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Section) do
        key "bad-view-variant"
        title "Bad"
        widget "requests.widgets.total", view_variant: :tiny
      end
    end

    assert_includes error.message, "unsupported view_variant"
  end

  def test_section_widget_view_variant_rejects_chip
    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Section) do
        key "legacy-chip-view-variant"
        title "Legacy"
        widget "requests.widgets.total", view_variant: :chip
      end
    end

    assert_includes error.message, "unsupported view_variant"
  end

  def test_backed_section_requires_context_access_recording_before_resolving_parent
    backed_section = Class.new(RecordingStudioAdmin::Section) do
      key "backed_without_context"
      title "Backed without context"
      recordable FakeRecordable,
                 find_or_create_by: -> { { name: "Section Area" } },
                 parent: -> { Object.new }
    end

    RecordingStudioAdmin.register_section(backed_section)

    with_singleton_stub(RecordingStudio, :root_recording_for, lambda { |*|
      flunk "parent recording should not be resolved"
    }) do
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.resolve_section(key: "backed_without_context", context: RecordingStudioAdmin::Context.new)
      end
    end
  end

  def test_backed_section_resolves_recordable_and_reuses_existing_recording
    parent_recordable = Object.new
    root_recording = Object.new
    child_recording = Object.new
    recorded_events = []
    stored_recording = nil
    previous_recording_constant_defined = RecordingStudio.const_defined?(:Recording, false)
    previous_recording_constant = RecordingStudio.const_get(:Recording) if previous_recording_constant_defined
    recording_class = Class.new do
      define_singleton_method(:unscoped) { self }
      define_singleton_method(:find_by) { |_attributes| stored_recording }
    end

    backed_section = Class.new(RecordingStudioAdmin::Section) do
      key "backed"
      title "Backed"
      recordable FakeRecordable,
                 find_or_create_by: ->(_section, context) { { name: context.params.fetch(:name) } },
                 parent: -> { parent_recordable }
    end

    RecordingStudioAdmin.register_section(backed_section)
    RecordingStudio.const_set(:Recording, recording_class)

    root_recording_for = lambda do |recordable|
      root_recording if recordable.equal?(parent_recordable)
    end

    with_singleton_stub(RecordingStudio, :root_recording_for, root_recording_for) do
      with_singleton_stub(RecordingStudio, :root_recording_or_self, ->(recording) { recording }) do
        with_singleton_stub(RecordingStudio, :record!, lambda { |**attributes|
          recorded_events << attributes
          stored_recording = child_recording
          Struct.new(:recording).new(child_recording)
        }) do
          context = allowed_context(params: { name: "Section Area" })

          first_result = with_access_allowed { RecordingStudioAdmin.resolve_section(key: "backed", context: context) }
          second_result = with_access_allowed { RecordingStudioAdmin.resolve_section(key: "backed", context: context) }

          assert_equal({ name: "Section Area" }, first_result.recordable.attributes)
          assert_equal child_recording, first_result.recording
          assert_equal child_recording, second_result.recording
          assert_equal 1, recorded_events.size
          assert_equal root_recording, recorded_events.first.fetch(:root_recording)
          assert_equal root_recording, recorded_events.first.fetch(:parent_recording)
        end
      end
    end
  ensure
    RecordingStudio.__send__(:remove_const, :Recording) if RecordingStudio.const_defined?(:Recording, false)
    RecordingStudio.const_set(:Recording, previous_recording_constant) if previous_recording_constant_defined
  end

  def test_backed_section_recovers_when_recording_insert_conflicts
    parent_recordable = Object.new
    root_recording = Object.new
    child_recording = Object.new
    record_attempts = 0
    stored_recording = nil
    previous_recording_constant_defined = RecordingStudio.const_defined?(:Recording, false)
    previous_recording_constant = RecordingStudio.const_get(:Recording) if previous_recording_constant_defined
    recording_class = Class.new do
      define_singleton_method(:unscoped) { self }
      define_singleton_method(:find_by) { |_attributes| stored_recording }
    end

    backed_section = Class.new(RecordingStudioAdmin::Section) do
      key "backed_insert_conflict"
      title "Backed insert conflict"
      recordable FakeRecordable,
                 find_or_create_by: -> { { name: "Section Area" } },
                 parent: -> { parent_recordable }
    end

    RecordingStudioAdmin.register_section(backed_section)
    RecordingStudio.const_set(:Recording, recording_class)

    root_recording_for = lambda do |recordable|
      root_recording if recordable.equal?(parent_recordable)
    end

    with_singleton_stub(RecordingStudio, :root_recording_for, root_recording_for) do
      with_singleton_stub(RecordingStudio, :root_recording_or_self, ->(recording) { recording }) do
        with_singleton_stub(RecordingStudio, :record!, lambda { |**_attributes|
          record_attempts += 1
          stored_recording = child_recording
          raise "duplicate key value violates unique constraint"
        }) do
          context = allowed_context

          result = with_access_allowed do
            RecordingStudioAdmin.resolve_section(key: "backed_insert_conflict", context: context)
          end

          assert_equal child_recording, result.recording
          assert_equal 1, record_attempts
        end
      end
    end
  ensure
    RecordingStudio.__send__(:remove_const, :Recording) if RecordingStudio.const_defined?(:Recording, false)
    RecordingStudio.const_set(:Recording, previous_recording_constant) if previous_recording_constant_defined
  end
end
