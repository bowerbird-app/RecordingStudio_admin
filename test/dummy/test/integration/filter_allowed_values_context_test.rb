# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class FilterAllowedValuesContextTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  FilterScopeRow = Struct.new(:status)

  class FilterScopeRelation
    attr_reader :rows

    def initialize(rows)
      @rows = rows
    end

    def count = rows.count
    def to_a = rows
    def limit(value) = self.class.new(rows.first(value))
    def offset(value) = self.class.new(rows.drop(value))
    def where(_conditions) = self
    def order(_order_hash) = self
  end

  test "zero-arg filter options still resolve on a live admin screen" do
    sign_in_admin_user
    ApiRequest.delete_all
    ApiRequest.create!(path: "/v1/ok", method: "GET", status: 200, latency_ms: 11, created_at: 2.minutes.ago,
                       updated_at: 2.minutes.ago)
    ApiRequest.create!(path: "/v1/fail", method: "POST", status: 500, latency_ms: 44, created_at: 1.minute.ago,
                       updated_at: 1.minute.ago)

    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success
    refute_includes response.body, "ArgumentError"

    live_context = controller.send(:recording_studio_admin_context)
    result = RecordingStudioAdmin.resolve_screen(key: "api_requests", context: live_context)
    status_filter = result.filters.find { |filter| filter.key == :status }

    assert_equal %w[200 500], status_filter.options[:values].map(&:to_s).sort
  end

  test "a live request context is passed to context-accepting allowed_values" do
    sign_in_admin_user
    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success

    live_context = controller.send(:recording_studio_admin_context)
    received = nil
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      values: lambda { |context|
        received = context
        root = context.controller.current_root_recording
        [root.class.name]
      }
    )

    values = definition.allowed_values(live_context)

    assert_same live_context, received
    assert_same controller, received.controller
    assert_equal live_context.current_actor, received.current_actor
    assert_equal [received.controller.current_root_recording.class.name], values
  end

  test "controller-scoped filter options match the table scope on a live request" do
    sign_in_admin_user
    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success

    live_context = controller.send(:recording_studio_admin_context)
    relation_class = FilterScopeRelation
    rows_for_root = [FilterScopeRow.new("ok"), FilterScopeRow.new("fail")]
    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "live_scoped_filters"
      title "Live scoped filters"
      query { |_context| relation_class.new(rows_for_root) }
      filter :status, options: lambda { |context|
        context.controller.current_root_recording
        rows_for_root.map(&:status)
      }
      table do
        column :status, sortable: false
      end
    end

    RecordingStudioAdmin.register_screen(screen)
    result = RecordingStudioAdmin.stub(:screen_enabled?, true) do
      RecordingStudioAdmin.resolve_screen(key: "live_scoped_filters", context: live_context)
    end
    status_filter = result.filters.find { |filter| filter.key == :status }

    assert_equal %w[fail ok], status_filter.options[:values].sort
    assert_equal %w[fail ok], result.table.rows.map(&:status).sort
  ensure
    RecordingStudioAdmin.registry.screens.delete("live_scoped_filters")
  end

  test "controller-scoped filter options fail without the change on a live request" do
    sign_in_admin_user
    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success

    live_context = controller.send(:recording_studio_admin_context)
    relation_class = FilterScopeRelation
    rows_for_root = [FilterScopeRow.new("ok")]
    screen = Class.new(RecordingStudioAdmin::Screen) do
      key "live_scoped_filters_legacy"
      title "Live scoped filters"
      query { |_context| relation_class.new(rows_for_root) }
      filter :status, options: ->(context) { [context.controller.current_root_recording.class.name] }
      table do
        column :status, sortable: false
      end
    end

    RecordingStudioAdmin.register_screen(screen)
    with_legacy_zero_arg_allowed_values do
      assert_raises(ArgumentError) do
        RecordingStudioAdmin.stub(:screen_enabled?, true) do
          RecordingStudioAdmin.resolve_screen(key: "live_scoped_filters_legacy", context: live_context)
        end
      end
    end
  ensure
    RecordingStudioAdmin.registry.screens.delete("live_scoped_filters_legacy")
  end

  test "a live request context-accepting allowed_values fails without the change" do
    sign_in_admin_user
    get "/admin/screens/api_requests", params: { anchor_url: root_url }

    assert_response :success

    live_context = controller.send(:recording_studio_admin_context)
    definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :status,
      :select,
      values: ->(context) { [context.controller.current_root_recording.class.name] }
    )

    with_legacy_zero_arg_allowed_values do
      assert_raises(ArgumentError) { definition.allowed_values(live_context) }
    end
  end

  private

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "filter-allowed-values@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end

    grant_admin_access_for_test!(recording: admin_root_recording_for_test, actor: user)
    sign_in user
  end

  def admin_root_recording_for_test
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end

  def with_legacy_zero_arg_allowed_values
    klass = RecordingStudioAdmin::Definitions::FilterDefinition
    original = klass.instance_method(:allowed_values)
    previous_verbose = $VERBOSE
    $VERBOSE = nil
    klass.define_method(:allowed_values) do |_context = nil|
      raw = options[:values] || options[:options]
      raw = raw.call if raw.respond_to?(:call)
      Array(raw).map(&:to_s)
    end
    yield
  ensure
    $VERBOSE = nil
    klass.define_method(:allowed_values, original)
    $VERBOSE = previous_verbose
  end
end
