# frozen_string_literal: true

require "test_helper"
require "active_record"
require "action_controller"
require "action_dispatch/testing/test_response"
require File.join(
  Gem.loaded_specs.fetch("recording_studio").full_gem_path,
  "app/helpers/recording_studio/layout_helper"
)
require File.expand_path("../app/controllers/recording_studio_admin/application_controller", __dir__)
require File.expand_path("../app/controllers/recording_studio_admin/screen_filter_options_controller", __dir__)

class AdminSafetyBehaviorTest < Minitest::Test
  Row = Struct.new(:name, :status)

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    @original_sections_resolver = RecordingStudioAdmin.configuration.admin_sections_resolver
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
    RecordingStudioAdmin.configuration.admin_sections_resolver = @original_sections_resolver
  end

  def test_admin_screens_sections_and_widgets_reject_an_actor_without_access
    register_read_screen
    denied = lambda do |**|
      false
    end

    with_singleton_stub(RecordingStudioAccessible, :authorized?, denied) do
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.resolve_screen(key: "safety_reads", context: allowed_context)
      end
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.resolve_section(key: "safety", context: allowed_context)
      end
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.resolve_widget(key: "widgets.safety.total", context: allowed_context)
      end
      assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
        RecordingStudioAdmin.available_widgets(context: allowed_context)
      end
    end
  end

  def test_admin_screens_reject_a_request_with_no_actor
    register_read_screen
    controller = access_controller(recording: Object.new)
    context = RecordingStudioAdmin::Context.new(controller: controller)

    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        RecordingStudioAdmin.resolve_screen(key: "safety_reads", context: context)
      end
    end

    assert_includes error.message, "current actor is not configured"
  end

  def test_view_actor_can_open_a_read_screen_but_not_a_mutating_action
    register_read_screen
    register_flag_resource
    record = Row.new("Ada", "active")
    view_only = lambda do |role:, **|
      role.to_sym == :view
    end

    screen = with_singleton_stub(RecordingStudioAccessible, :authorized?, view_only) do
      RecordingStudioAdmin.resolve_screen(key: "safety_reads", context: allowed_context)
    end

    assert_equal "Safety reads", screen.title

    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, view_only) do
        RecordingStudioAdmin.resolve_resource_action(
          key: "safety_people",
          action: :remove,
          context: allowed_context,
          record: record
        )
      end
    end

    assert_includes error.message, "cannot access"
  end

  def test_destructive_actions_ask_for_confirmation
    register_read_screen
    context = allowed_context
    row = Row.new("Ada", "active")

    screen = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "safety_reads", context: context)
    end
    delete_action = screen.table.actions.find { |action| action.name == :delete_row }
    named_action = screen.table.actions.find { |action| action.name == :archive_row }
    read_action = screen.table.actions.find { |action| action.name == :open_row }

    delete_resolved = delete_action.resolve(row, context)
    named_resolved = named_action.resolve(row, context)
    read_resolved = read_action.resolve(row, context)

    assert delete_resolved.destructive
    assert_equal :delete, delete_resolved.method
    assert_equal "Are you sure?", delete_resolved.confirm
    assert_equal "Archive Ada?", named_resolved.confirm
    assert named_resolved.destructive
    assert_nil read_resolved.confirm
    refute read_resolved.destructive
  end

  def test_resource_delete_is_destructive_and_asks_for_confirmation
    register_flag_resource
    record = Row.new("Ada", "active")

    action = with_access_allowed do
      RecordingStudioAdmin.resolve_resource_action(
        key: "safety_people",
        action: :remove,
        context: allowed_context,
        record: record
      )
    end
    resolved = action.resolve(record, allowed_context)

    assert_equal :admin, action.required_access_role
    assert resolved.destructive
    assert_equal "Are you sure?", resolved.confirm
  end

  def test_screen_buttons_hide_when_unavailable_and_drop_unsafe_urls
    register_read_screen

    screen = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "safety_reads", context: allowed_context)
    end

    assert_equal %i[export unsafe], screen.buttons.map(&:name)
    assert_equal "/admin/export", screen.buttons.first.url
    assert_equal "#", screen.buttons.last.url
  end

  def test_screen_definition_rejects_unknown_scope_columns_and_actions
    scope_error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Screen) do
        key "bad_scope"
        availability_scope :sideways
      end
    end
    assert_includes scope_error.message, "unsupported value"

    action_error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Screen) do
        key "bad_action"
        table { admin_action "lonely" }
      end
    end
    assert_includes action_error.message, "resource key and action key"

    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "bad_columns"
      query { |_context| [] }
      table do
        column :name
        default_columns :missing
      end
    end
    RecordingStudioAdmin.register_screen(screen)

    column_error = assert_raises(ArgumentError) do
      with_access_allowed do
        RecordingStudioAdmin.resolve_screen(key: "bad_columns", context: allowed_context)
      end
    end
    assert_includes column_error.message, "Unknown default columns: missing"
  end

  def test_column_display_options_receive_the_row_and_context_they_declare
    context = allowed_context
    row = Row.new("Ada", "active")
    table = RecordingStudioAdmin::TableDefinition.new do
      column :plain, display_options: -> { { tone: "zero" } }
      column :from_row, display_options: ->(record) { { tone: record.status } }
      column :from_context, display_options: ->(record, current) { { tone: "#{record.name}-#{current.current_actor}" } }
    end

    assert_equal({ tone: "zero" }, table.columns[0].display_options_for(row, context, "plain"))
    assert_equal({ tone: "active" }, table.columns[1].display_options_for(row, context, "active"))
    assert_equal({ tone: "Ada-actor" }, table.columns[2].display_options_for(row, context, "Ada"))
  end

  def test_missing_widget_and_non_hash_widget_params_are_rejected
    register_widget_screen

    missing = assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      with_access_allowed do
        RecordingStudioAdmin::Resolvers::ScreenResolver.resolve_widget(
          key: "safety_widgets",
          widget_key: "widgets.safety.missing",
          context: allowed_context
        )
      end
    end
    assert_includes missing.message, "is not referenced"

    resolved = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "safety_widgets", context: allowed_context)
    end
    assert_equal "Total", resolved.widgets.first.title
  end

  def test_widget_usage_index_picks_the_matching_card_and_strips_unsafe_links
    register_indexed_widgets

    second = with_access_allowed do
      RecordingStudioAdmin::Resolvers::ScreenResolver.resolve_widget(
        key: "indexed_widgets",
        widget_key: "widgets.safety.total",
        usage_index: 1,
        context: allowed_context
      )
    end
    first = with_access_allowed do
      RecordingStudioAdmin::Resolvers::ScreenResolver.resolve_widget(
        key: "indexed_widgets",
        widget_key: "widgets.safety.total",
        usage_index: 0,
        view_variant: "__default__",
        context: allowed_context
      )
    end

    assert_equal "Second", second.title
    assert_equal "First", first.title
    assert_equal "#", second.link_to
  end

  def test_grouped_count_failure_falls_back_to_an_unordered_count
    relation = StatementInvalidRelation.new(4)
    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "counted"
      query { |_context| relation }
      table { column :name }
    end
    RecordingStudioAdmin.register_screen(screen)

    resolved = with_access_allowed do
      RecordingStudioAdmin.resolve_screen(key: "counted", context: allowed_context)
    end

    assert_equal 4, resolved.query_result.count
    assert_equal 4, resolved.table.result.total_count
  end

  def test_filter_options_reject_unknown_hidden_and_disabled_screens
    register_within_screen
    missing = filter_controller(key: "missing", filter_key: "folder")

    assert_raises(RecordingStudioAdmin::DefinitionNotFound) { missing.index }

    hidden = filter_controller(key: "within_screen", filter_key: "folder")
    hidden_error = assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      with_access_allowed { hidden.index }
    end
    assert_includes hidden_error.message, "is not visible"

    open_screen = Class.new(RecordingStudioAdmin::Screen) do
      key "open_screen"
      query { |_context| [] }
    end
    RecordingStudioAdmin.register_screen(open_screen)
    unavailable = filter_controller(key: "open_screen", filter_key: "folder")
    unavailable_error = assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      with_access_allowed { unavailable.index }
    end
    assert_includes unavailable_error.message, "is not available"

    RecordingStudioAdmin.configuration.admin_sections_resolver = ->(_recording) { [] }
    disabled = filter_controller(key: "open_screen", filter_key: "folder")
    disabled_error = assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      with_access_allowed { disabled.index }
    end
    assert_includes disabled_error.message, "is not enabled"
  end

  def test_available_widgets_reject_an_unknown_placement_and_honor_custom_scopes
    recording = Object.new
    recording.define_singleton_method(:parent_recording) { nil }
    child = Object.new
    child.define_singleton_method(:parent_recording) { recording }
    rootish = Object.new
    rootish.define_singleton_method(:root_recording) { rootish }
    nested = Object.new
    nested.define_singleton_method(:root_recording) { rootish }

    register_scope_sections
    error = assert_raises(ArgumentError) do
      RecordingStudioAdmin.available_widgets(context: allowed_context, placement: :sideways)
    end
    assert_includes error.message, "placement must be one of"

    widgets = with_access_allowed do
      RecordingStudioAdmin.available_widgets(
        context: allowed_context(recording: child),
        recording: child,
        placement: :descendant
      )
    end
    items = with_access_allowed do
      RecordingStudioAdmin.available_admin_items(
        context: allowed_context(recording: rootish),
        recording: rootish,
        placement: :root
      )
    end

    widget_keys = widgets.map(&:key)
    assert_includes widget_keys, "widgets.safety.child"
    assert_includes widget_keys, "widgets.safety.zero"
    refute_includes widget_keys, "widgets.safety.root"
    assert_includes items.map(&:key), "scope_root"
    refute_includes items.map(&:key), "scope_child"
    assert_includes(
      with_access_allowed do
        RecordingStudioAdmin.available_admin_items(
          context: allowed_context(recording: nested),
          recording: nested,
          placement: :descendant
        ).map(&:key)
      end,
      "scope_nested"
    )
  end

  def test_activity_log_labels_outcomes_and_period_change
    blank = log_row(nil, nil, nil, nil)
    typed = log_row("User", nil, "Page", nil)
    identified = log_row("User", 4, "Page", 9)

    assert_equal "System", RecordingStudioAdmin::AdminActivityLogsScreen.actor_label(blank)
    assert_equal "User", RecordingStudioAdmin::AdminActivityLogsScreen.actor_label(typed)
    assert_equal "User #4", RecordingStudioAdmin::AdminActivityLogsScreen.actor_label(identified)
    assert_equal "Page #9", RecordingStudioAdmin::AdminActivityLogsScreen.record_label(identified)
    assert_equal "people.remove", RecordingStudioAdmin::AdminActivityLogsScreen.action_label(identified)
    assert_equal :warning, RecordingStudioAdmin::AdminActivityLogsScreen.outcome_badge_style("validation_failed")
    assert_equal :default, RecordingStudioAdmin::AdminActivityLogsScreen.outcome_badge_style("queued")
    assert_equal "%100\\%%", RecordingStudioAdmin::AdminActivityLogsSupport.safe_like("100%")

    label = RecordingStudioAdmin::AdminActivityLogsSupport.period_change_label(counting_relation(8, 4))
    assert_equal "+100%", label
    assert_equal "0%", RecordingStudioAdmin::AdminActivityLogsSupport.period_change_label(counting_relation(0, 0))

    had_model = Object.const_defined?(:AdminAuditLog)
    original = Object.send(:remove_const, :AdminAuditLog) if had_model
    error = assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      RecordingStudioAdmin::AdminActivityLogsScreen.audit_log_model
    end
    assert_includes error.message, "AdminAuditLog"
    Object.const_set(:AdminAuditLog, Class.new)
    assert_equal AdminAuditLog, RecordingStudioAdmin::AdminActivityLogsScreen.audit_log_model
  ensure
    Object.send(:remove_const, :AdminAuditLog) if Object.const_defined?(:AdminAuditLog)
    Object.const_set(:AdminAuditLog, original) if had_model
  end

  private

  def register_read_screen
    section = Class.new(RecordingStudioAdmin::Section) do
      key "safety"
      title "Safety"
    end
    widget = RecordingStudioAdmin::Widget.new("widgets.safety.total") { title "Total" }
    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "safety_reads"
      title "Safety reads"
      button :export, text: "Export", url: "/admin/export"
      button :hidden, text: "Hidden", url: "/secret", visible_if: ->(_context) { false }
      button :unsafe, text: "Unsafe", url: "javascript:alert(1)"
      query { |_context| [] }
      table do
        column :name
        action :open_row, text: "Open", url: "/admin/rows/1"
        action :delete_row, text: "Delete", url: "/admin/rows/1", method: :delete
        action :archive_row,
               text: "Archive",
               url: "/admin/rows/1",
               method: :post,
               destructive: true,
               confirm: ->(row, _context) { "Archive #{row.name}?" }
      end
    end
    RecordingStudioAdmin.register_section(section)
    RecordingStudioAdmin.register_widget(widget)
    RecordingStudioAdmin.register_screen(screen)
    RecordingStudioAdmin.register_section(section)
  end

  def register_flag_resource
    section = Class.new(RecordingStudioAdmin::Section) do
      key "safety_people_section"
      title "People"
    end
    resource = Class.new(RecordingStudioAdmin::Resource) do
      key "safety_people"
      section "safety_people_section"
      action :remove, text: "Remove", url: "/admin/people/1", method: :delete
    end
    RecordingStudioAdmin.register_section(section)
    RecordingStudioAdmin.register_resource(resource)
  end

  def register_widget_screen
    widget = RecordingStudioAdmin::Widget.new("widgets.safety.total") do
      title "Total"
      value { 1 }
    end
    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "safety_widgets"
      title "Widgets"
      query { |_context| [] }
      widget "widgets.safety.total"
    end
    RecordingStudioAdmin.register_widget(widget)
    RecordingStudioAdmin.register_screen(screen)
  end

  def register_indexed_widgets
    widget = RecordingStudioAdmin::Widget.new("widgets.safety.total") do
      title "Total"
      value { 1 }
    end
    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "indexed_widgets"
      title "Indexed"
      query { |_context| [] }
      widget "widgets.safety.total", title: "First"
      widget "widgets.safety.total", title: "Second", link_to: "javascript:alert(1)"
    end
    RecordingStudioAdmin.register_widget(widget)
    RecordingStudioAdmin.register_screen(screen)
  end

  def register_within_screen
    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "within_screen"
      title "Within"
      visible_if ->(_context) { false }
      query { |_context| [] }
    end
    RecordingStudioAdmin.register_screen(screen)
  end

  def register_scope_sections
    zero = Class.new(RecordingStudioAdmin::Section) do
      key "scope_zero"
      title "Zero"
      availability_scope { true }
      widget "widgets.safety.zero"
    end
    one = Class.new(RecordingStudioAdmin::Section) do
      key "scope_child"
      title "Child"
      availability_scope { |recording| recording.respond_to?(:parent_recording) && recording.parent_recording.present? }
      widget "widgets.safety.child"
    end
    two = Class.new(RecordingStudioAdmin::Section) do
      key "scope_root"
      title "Root"
      availability_scope do |recording, _context|
        recording.respond_to?(:root_recording) && recording.root_recording.equal?(recording)
      end
      widget "widgets.safety.root"
    end
    three = Class.new(RecordingStudioAdmin::Section) do
      key "scope_nested"
      title "Nested"
      availability_scope { |_recording, _context, placement| placement == :descendant }
      widget "widgets.safety.nested"
    end
    [zero, one, two, three].each do |section|
      RecordingStudioAdmin.register_section(section)
    end
    %w[zero child root nested].each do |name|
      RecordingStudioAdmin.register_widget(RecordingStudioAdmin::Widget.new("widgets.safety.#{name}") { title name })
    end
  end

  def allowed_context(recording: nil)
    RecordingStudioAdmin::Context.new(
      current_actor: :actor,
      controller: access_controller(recording: recording || Object.new)
    )
  end

  def access_controller(recording:)
    Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
    end.new
  end

  def with_access_allowed(&)
    with_singleton_stub(RecordingStudioAccessible, :authorized?, true, &)
  end

  def filter_controller(key:, filter_key:)
    recording = Object.new
    controller = RecordingStudioAdmin::ScreenFilterOptionsController.new
    controller.set_request! ActionDispatch::TestRequest.create
    controller.set_response! ActionDispatch::TestResponse.new
    params = ActionController::Parameters.new(key: key, filter_key: filter_key)
    controller.define_singleton_method(:params) { params }
    controller.define_singleton_method(:current_actor) { :actor }
    controller.define_singleton_method(:recording_studio_admin_access_recording) { recording }
    controller
  end

  def counting_relation(*counts)
    queue = counts.dup
    relation = Object.new
    relation.define_singleton_method(:where) do |_conditions|
      scoped = Object.new
      scoped.define_singleton_method(:count) { queue.shift }
      scoped.define_singleton_method(:distinct) { scoped }
      scoped
    end
    relation
  end

  def log_row(actor_type, actor_id, record_type, record_id)
    Struct.new(:actor_type, :actor_id, :record_type, :record_id, :resource_key, :action_key).new(
      actor_type, actor_id, record_type, record_id, "people", "remove"
    )
  end

  class StatementInvalidRelation
    def initialize(total)
      @total = total
    end

    def count
      raise ActiveRecord::StatementInvalid, "grouped select"
    end

    def except(*)
      total = @total
      counted = Object.new
      counted.define_singleton_method(:count) { total }
      counted
    end

    def order(*) = self
    def limit(*) = self
    def offset(*) = self
    def to_a = []
  end
end
