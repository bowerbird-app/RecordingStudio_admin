# frozen_string_literal: true

require "test_helper"

class ResourceTest < Minitest::Test
  ResourceRecord = Struct.new(:id, :email, :status, keyword_init: true) do
    def to_param = id.to_s
  end

  class UsersSection < RecordingStudioAdmin::Section
    key "users"
    title "Users"
  end

  class UsersResource < RecordingStudioAdmin::Resource
    key "users"
    section "users"
    title "Managed users"
    subtitle "Edit users"
      action :show,
        text: "Show",
        icon: "eye",
        url: ->(record, context) { context.controller.admin_user_path(record) }
      action :edit,
        text: "Edit",
        icon: "pencil-square",
        url: ->(record, context) { context.controller.edit_admin_user_path(record) },
        required_role: :admin
      action :suspend,
        text: "Suspend",
        icon: "flag",
        method: :post,
        confirm: ->(record, _context) { "Suspend #{record.email}?" },
        url: ->(record, context) { context.controller.suspend_admin_user_path(record) },
        visible_if: ->(record, _context) { record.status != "disabled" }
  end

  class HiddenSection < RecordingStudioAdmin::Section
    key "hidden"
    visible_if ->(_context) { false }
  end

  class HiddenResource < RecordingStudioAdmin::Resource
    key "hidden_users"
    section "hidden"
    action :edit, text: "Edit", url: "/hidden"
  end

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.register_section(UsersSection)
    RecordingStudioAdmin.register_section(HiddenSection)
    RecordingStudioAdmin.register_resource(UsersResource)
    RecordingStudioAdmin.register_resource(HiddenResource)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
  end

  def test_resource_action_resolution_authorizes_against_admin_access_recording
    access_recording = Object.new
    record = ResourceRecord.new(id: 1, email: "first@example.com", status: "active")
    context = allowed_context(recording: access_recording)
    authorized_recordings = []

    authorizer = lambda do |actor:, recording:, role:|
      assert_equal :actor, actor
      assert_equal :admin, role
      authorized_recordings << recording
      true
    end

    resolved = with_singleton_stub(RecordingStudioAccessible, :authorized?, authorizer) do
      RecordingStudioAdmin.resolve_resource_action(key: "users", action: :suspend, context: context, record: record)
    end

    assert_equal [access_recording], authorized_recordings
    row_action = resolved.resolve(record, context)
    assert_equal "Suspend", row_action.text
    assert_equal "/admin/users/1/suspend", row_action.url
    assert_equal :post, row_action.method
    assert_equal "Suspend first@example.com?", row_action.confirm
  end

  def test_read_resource_action_uses_configured_role_by_default
    record = ResourceRecord.new(id: 1, email: "first@example.com", status: "active")
    context = allowed_context
    authorized_roles = []

    authorizer = lambda do |actor:, recording:, role:|
      assert_equal :actor, actor
      assert_same context.access_recording, recording
      authorized_roles << role
      true
    end

    resolved = with_singleton_stub(RecordingStudioAccessible, :authorized?, authorizer) do
      RecordingStudioAdmin.resolve_resource_action(key: "users", action: :show, context: context, record: record)
    end

    assert_equal [:view], authorized_roles
    assert_equal "/admin/users/1", resolved.resolve(record, context).url
  end

  def test_resource_action_resolution_enforces_explicit_required_role
    record = ResourceRecord.new(id: 1, email: "first@example.com", status: "active")
    authorizer = ->(role:, **) { role == :view }

    assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, authorizer) do
        RecordingStudioAdmin.resolve_resource_action(key: "users", action: :edit, context: allowed_context, record: record)
      end
    end
  end

  def test_resource_action_resolution_rejects_unconfigured_actions
    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        RecordingStudioAdmin.resolve_resource_action(key: "users", context: allowed_context, action: :destroy)
      end
    end

    assert_includes error.message, "does not define action destroy"
  end

  def test_context_resolves_registered_admin_action_path
    record = ResourceRecord.new(id: 2, email: "second@example.com", status: "active")
    context = allowed_context
    resolved = with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      context.admin_action("users", :edit, record)
    end

    assert_equal "Edit", resolved.text
    assert_equal "/admin/users/2/edit", resolved.url
    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      assert_equal "/admin/users/2/edit", context.admin_action_path("users", :edit, record)
    end
  end

  def test_resource_action_visibility_is_enforced
    record = ResourceRecord.new(id: 2, email: "second@example.com", status: "disabled")

    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        RecordingStudioAdmin.resolve_resource_action(key: "users", action: :suspend, context: allowed_context, record: record)
      end
    end

    assert_includes error.message, "action suspend is not visible"
  end

  def test_table_admin_action_resolves_registered_action_and_hides_unavailable_rows
    table = RecordingStudioAdmin::TableDefinition.new do
      admin_action "users.suspend"
    end
    active_record = ResourceRecord.new(id: 1, email: "first@example.com", status: "active")
    disabled_record = ResourceRecord.new(id: 2, email: "second@example.com", status: "disabled")

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      resolved = table.actions.first.resolve(active_record, allowed_context)
      assert_equal "Suspend", resolved.text
      assert_equal "/admin/users/1/suspend", resolved.url
      assert_nil table.actions.first.resolve(disabled_record, allowed_context)
    end
  end

  def test_table_admin_action_hides_rows_when_required_role_is_denied
    table = RecordingStudioAdmin::TableDefinition.new do
      admin_action "users.edit"
    end
    record = ResourceRecord.new(id: 1, email: "first@example.com", status: "active")
    authorizer = ->(role:, **) { role == :view }

    with_singleton_stub(RecordingStudioAccessible, :authorized?, authorizer) do
      assert_nil table.actions.first.resolve(record, allowed_context)
    end
  end

  def test_resource_action_resolution_honors_section_visibility
    assert_raises(RecordingStudioAdmin::DefinitionNotFound) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        RecordingStudioAdmin.resolve_resource_action(key: "hidden_users", context: allowed_context, action: :edit)
      end
    end
  end

  private

  def allowed_context(recording: Object.new)
    controller = Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
      define_method(:admin_user_path) { |record| "/admin/users/#{record.to_param}" }
      define_method(:edit_admin_user_path) { |record| "/admin/users/#{record.to_param}/edit" }
      define_method(:suspend_admin_user_path) { |record| "/admin/users/#{record.to_param}/suspend" }
    end.new

    RecordingStudioAdmin::Context.new(current_actor: :actor, controller: controller)
  end
end