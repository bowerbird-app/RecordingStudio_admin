# frozen_string_literal: true

require "test_helper"

class ResolverTest < Minitest::Test
  Row = Struct.new(:created_at, :status, :name)

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

    def order(order_hash)
      ordered = rows.sort_by { |row| row.public_send(order_hash.keys.first) }
      ordered.reverse! if order_hash.values.first.to_s == "desc"
      self.class.new(ordered)
    end
  end

  class RequestsScreen < RecordingStudioAdmin::Screen
    key "requests"
    title "Requests"
    subtitle "Traffic"
    query { |_context| ArrayRelation.new([Row.new(Time.now, 200, "b"), Row.new(Time.now, 500, "a")]) }
    filter :group_by, default: :day
    filter :state, options: -> { %w[open closed] }

    chart do
      title "Traffic"
      type :line
      series { [] }
    end

    table do
      column :name
      column(
        :status,
        display: :badge,
        display_options: lambda { |_row, _context, value|
          { text: value.to_s, style: value.to_i >= 500 ? :danger : :success, size: :sm }
        }
      )
      action :unsafe, text: "Unsafe", url: ->(_row, _context) { "javascript:alert(1)" }
      paginate per_page: 1
    end

    widget :total do
      title "Total"
      value { |context| context.query_result.count }
    end

    widget :recent_statuses do
      type :list
      title "Recent statuses"
      items { |_context| ["200 OK", "500 Error"] }
    end

    widget :traffic_preview do
      type :chart
      title "Traffic preview"
      chart_type :bar
      series { [{ name: "Requests", data: [{ x: "Jan", y: 2 }] }] }
    end

    widget :legacy_total do
      type :stat
      title "Legacy total"
      value { |context| context.query_result.count }
    end
  end

  class HiddenScreen < RecordingStudioAdmin::Screen
    key "hidden"
    visible_if ->(_context) { false }
    query { |_context| ArrayRelation.new([]) }
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    title "Root"
    link :requests, text: "Requests", url: ->(context) { context.admin_screen_path("requests") }, style: :primary
    widget "requests.widgets.total"
  end

  class HiddenSection < RecordingStudioAdmin::Section
    key "hidden"
    visible_if ->(_context) { false }
    title "Hidden"
  end

  FakeRecordable = Struct.new(:attributes) do
    def self.find_or_create_by!(attributes)
      new(attributes)
    end
  end

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.register_screen(RequestsScreen)
    RecordingStudioAdmin.register_screen(HiddenScreen)
    RecordingStudioAdmin.register_section(RootSection)
    RecordingStudioAdmin.register_section(HiddenSection)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
  end

  def test_resolve_screen_returns_structured_result_without_html
    context = RecordingStudioAdmin::Context.new(params: { sort: "name", direction: "asc" })

    result = RecordingStudioAdmin.resolve_screen(key: "requests", context: context)

    assert_equal "Requests", result.title
    assert_equal 2, result.query_result.count
    assert_equal 1, result.table.rows.size
    assert_equal "name", result.table.result.sort
    assert_equal :day, context.filter_value(:group_by)
    assert_equal 2, result.widgets.first.value
    assert_equal :number, result.widgets.first.type
    assert_equal :list, result.widgets.find { |widget| widget.key == "requests.widgets.recent_statuses" }.type
    traffic_preview = result.widgets.find { |widget| widget.key == "requests.widgets.traffic_preview" }
    assert_equal :chart, traffic_preview.type
    assert_equal :bar, traffic_preview.chart_type
    assert_equal [{ name: "Requests", data: [{ x: "Jan", y: 2 }] }], traffic_preview.series
    assert_equal "#", result.table.actions.first.resolve(result.table.rows.first, context).url
    status_column = result.table.columns.find { |column| column.key == :status }
    assert_equal :badge, status_column.display
    assert_equal(
      { text: "500", style: :danger, size: :sm },
      status_column.display_options_for(result.table.rows.first, context, 500)
    )
  end

  def test_legacy_stat_widgets_are_normalized_to_number
    widget = RecordingStudioAdmin.resolve_widget(key: "requests.widgets.legacy_total", context: RecordingStudioAdmin::Context.new)

    assert_equal :number, widget.type
    assert_equal 2, widget.value
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

  def test_proc_backed_filter_options_are_resolved
    result = RecordingStudioAdmin.resolve_screen(key: "requests", context: RecordingStudioAdmin::Context.new)

    assert_equal %w[open closed], result.filters.find { |filter| filter.key == :state }.options[:values]
  end

  def test_context_fallback_paths_use_configured_default_mount_path
    original_mount_path = RecordingStudioAdmin.configuration.default_mount_path
    RecordingStudioAdmin.configuration.default_mount_path = "/backoffice"

    context = RecordingStudioAdmin::Context.new

    assert_equal "/backoffice/screens/requests", context.admin_screen_path("requests")
    assert_equal "/backoffice/sections/root", context.admin_section_path("root")
  ensure
    RecordingStudioAdmin.configuration.default_mount_path = original_mount_path
  end

  def test_missing_screen_raises_specific_error
    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      RecordingStudioAdmin.resolve_screen(key: "missing", context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_hidden_screen_and_section_raise_not_found
    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      RecordingStudioAdmin.resolve_screen(key: "hidden", context: RecordingStudioAdmin::Context.new)
    end

    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      RecordingStudioAdmin.resolve_section(key: "hidden", context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_pagination_page_is_capped
    context = RecordingStudioAdmin::Context.new(params: { page: "999999" })

    result = RecordingStudioAdmin.resolve_screen(key: "requests", context: context)

    assert_equal 1_000, result.table.result.current_page
  end

  def test_resolve_section_links_widgets_and_missing_widget
    context = RecordingStudioAdmin::Context.new
    section = RecordingStudioAdmin.resolve_section(key: "root", context: context)

    assert_equal "Root", section.title
    assert_equal "/admin/screens/requests", section.links.first.url
    assert_equal "requests.widgets.total", section.widgets.first.key
    assert_nil section.recordable
    assert_nil section.recording
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

    RecordingStudio.stub(:root_recording_for, root_recording_for) do
      RecordingStudio.stub(:root_recording_or_self, ->(recording) { recording }) do
        RecordingStudio.stub(:record!, lambda { |**attributes|
          recorded_events << attributes
          stored_recording = child_recording
          Struct.new(:recording).new(child_recording)
        }) do
          context = RecordingStudioAdmin::Context.new(params: { name: "Section Area" })

          first_result = RecordingStudioAdmin.resolve_section(key: "backed", context: context)
          second_result = RecordingStudioAdmin.resolve_section(key: "backed", context: context)

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
end
