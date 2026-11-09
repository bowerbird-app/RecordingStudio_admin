# frozen_string_literal: true

require "test_helper"

class FilterAllowedValuesContextTest < Minitest::Test
  Row = Struct.new(:status)

  class ArrayRelation
    attr_reader :rows

    def initialize(rows)
      @rows = rows
    end

    def count = rows.count
    def to_a = rows
    def limit(value) = self.class.new(rows.first(value))
    def offset(value) = self.class.new(rows.drop(value))

    def where(conditions)
      conditions.reduce(self) do |relation, (field, expected)|
        self.class.new(relation.rows.select { |row| row.public_send(field) == expected })
      end
    end

    def order(_order_hash) = self
  end

  class ScopedFilterScreen < RecordingStudioAdmin::Screen
    key "scoped_filters"
    title "Scoped filters"
    query do |context|
      root = context.controller.current_root_recording
      ArrayRelation.new(scoped_rows(root))
    end
    filter :status, options: lambda { |context|
      root = context.controller.current_root_recording
      scoped_rows(root).map(&:status)
    }
    table do
      column :status, sortable: false
    end

    def self.scoped_rows(root)
      [
        Row.new("ok"),
        Row.new("fail")
      ].select { root.equal?(ROOT_A) }
    end
  end

  ROOT_A = Object.new
  ROOT_B = Object.new

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.register_screen(ScopedFilterScreen)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
  end

  def test_context_accepting_allowed_values_receive_the_request_context
    received = nil
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      values: lambda { |context|
        received = context
        %w[ok]
      }
    )
    controller = request_controller
    actor = Object.new
    context = RecordingStudioAdmin::Context.new(controller: controller, current_actor: actor)

    assert_equal %w[ok], definition.allowed_values(context)
    assert_same context, received
    assert_same controller, received.controller
    assert_same actor, received.current_actor
  end

  def test_context_accepting_allowed_values_fail_without_the_change
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      values: ->(context) { [context.controller.current_root_recording.object_id.to_s] }
    )
    context = RecordingStudioAdmin::Context.new(controller: request_controller, current_actor: Object.new)

    with_legacy_zero_arg_allowed_values do
      assert_raises(ArgumentError) { definition.allowed_values(context) }
    end
  end

  def test_zero_arg_allowed_values_still_work
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      options: -> { %w[open closed] }
    )
    context = RecordingStudioAdmin::Context.new(controller: request_controller, current_actor: Object.new)

    assert_equal %w[open closed], definition.allowed_values(context)
    assert_equal "open", definition.normalize({ status: "open" }, context)
    assert_nil definition.normalize({ status: "deleted" }, context)
  end

  def test_zero_arg_allowed_values_fail_when_context_is_always_passed
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      options: -> { %w[open closed] }
    )
    context = RecordingStudioAdmin::Context.new(controller: request_controller, current_actor: Object.new)

    with_context_always_passed_to_allowed_values do
      assert_raises(ArgumentError) { definition.allowed_values(context) }
    end
  end

  def test_controller_scoped_filter_options_match_the_table_scope
    context = allowed_context(current_root_recording: ROOT_A)

    result = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "scoped_filters", context: context)
    end

    status_filter = result.filters.find { |filter| filter.key == :status }

    assert_equal %w[fail ok], status_filter.options[:values].sort
    assert_equal %w[fail ok], result.table.rows.map(&:status).sort
  end

  def test_controller_scoped_filter_options_fail_without_the_change
    context = allowed_context(current_root_recording: ROOT_A)

    with_legacy_zero_arg_allowed_values do
      error = assert_raises(ArgumentError) do
        with_access_allowed { RecordingStudioAdmin.resolve_screen(key: "scoped_filters", context: context) }
      end

      assert_match(/wrong number of arguments/, error.message)
    end
  end

  def test_other_root_does_not_leak_into_filter_options
    context = allowed_context(current_root_recording: ROOT_B)

    result = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "scoped_filters", context: context)
    end

    status_filter = result.filters.find { |filter| filter.key == :status }

    assert_empty status_filter.options[:values]
    assert_empty result.table.rows
  end

  private

  def request_controller(recording: nil, current_root_recording: ROOT_A)
    recording ||= current_root_recording
    Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
      define_method(:current_root_recording) { current_root_recording }
    end.new
  end

  def allowed_context(current_root_recording:)
    RecordingStudioAdmin::Context.new(
      params: {},
      current_actor: :actor,
      controller: request_controller(current_root_recording: current_root_recording)
    )
  end

  def with_access_allowed(&)
    with_singleton_stub(RecordingStudioAccessible, :authorized?, true, &)
  end

  def with_legacy_zero_arg_allowed_values(&)
    redefine_allowed_values(->(raw, _context) { raw.call }, &)
  end

  def with_context_always_passed_to_allowed_values(&)
    redefine_allowed_values(->(raw, context) { raw.call(context) }, &)
  end

  def redefine_allowed_values(invoke)
    klass = RecordingStudioAdmin::Definitions::FilterDefinition
    original = klass.instance_method(:allowed_values)
    previous_verbose = $VERBOSE
    $VERBOSE = nil
    klass.define_method(:allowed_values) do |context = nil|
      raw = options[:values] || options[:options]
      raw = invoke.call(raw, context) if raw.respond_to?(:call)
      Array(raw).map(&:to_s)
    end
    yield
  ensure
    $VERBOSE = nil
    klass.define_method(:allowed_values, original)
    $VERBOSE = previous_verbose
  end
end
