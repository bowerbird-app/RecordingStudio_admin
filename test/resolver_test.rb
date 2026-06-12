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

    chart do
      title "Traffic"
      type :line
      series { [] }
    end

    table do
      column :name
      column :status
      paginate per_page: 1
    end

    widget :total do
      title "Total"
      value { |context| context.query_result.count }
    end
  end

  class RootSection < RecordingStudioAdmin::Section
    key "root"
    title "Root"
    link :requests, text: "Requests", url: ->(context) { context.admin_screen_path("requests") }, style: :primary
    widget "requests.widgets.total"
  end

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.register_screen(RequestsScreen)
    RecordingStudioAdmin.register_section(RootSection)
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
  end

  def test_missing_screen_raises_specific_error
    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      RecordingStudioAdmin.resolve_screen(key: "missing", context: RecordingStudioAdmin::Context.new)
    end
  end

  def test_resolve_section_links_widgets_and_missing_widget
    context = RecordingStudioAdmin::Context.new
    section = RecordingStudioAdmin.resolve_section(key: "root", context: context)

    assert_equal "Root", section.title
    assert_equal "/admin/screens/requests", section.links.first.url
    assert_equal "requests.widgets.total", section.widgets.first.key
  end
end
