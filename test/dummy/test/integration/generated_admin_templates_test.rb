# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class GeneratedAdminTemplatesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  TEMPLATE_ROOT = Rails.root.join("../../lib/generators/recording_studio_admin")
  ADMIN_ROOT_TEMPLATES = TEMPLATE_ROOT.join("admin_root/templates")
  SCHEMA = "admin_template_check"

  class << self
    def load_generated_templates
      return if @generated_templates_loaded

      load ADMIN_ROOT_TEMPLATES.join("app/models/admin_audit_log.rb").to_s
      load ADMIN_ROOT_TEMPLATES.join("app/models/admin_root.rb").to_s
      load ADMIN_ROOT_TEMPLATES.join("app/controllers/admin/base_controller.rb").to_s
      Admin::RootController.send(:remove_const, :SEARCH_RESULTS_FRAME_ID)
      load ADMIN_ROOT_TEMPLATES.join("app/controllers/admin/root_controller.rb").to_s
      @generated_templates_loaded = true
    end
  end

  setup do
    self.class.load_generated_templates
    @previous_authentication_method = RecordingStudioAdmin.configuration.authentication_method
    @previous_actor_method = RecordingStudioAdmin.configuration.current_actor_method
    RecordingStudioAdmin.configuration.authentication_method = :authenticate_user!
    RecordingStudioAdmin.configuration.current_actor_method = :current_user
  end

  teardown do
    RecordingStudioAdmin.configuration.authentication_method = @previous_authentication_method
    RecordingStudioAdmin.configuration.current_actor_method = @previous_actor_method
  end

  test "the generated admin root asks a signed-in person to authenticate when no method is configured" do
    RecordingStudioAdmin.configuration.authentication_method = nil
    sign_in_user("generated-template-signed-in@example.com")

    get "/admin/root"

    assert_response :unauthorized
  end

  test "the generated admin root rejects a signed-in person without access" do
    sign_in_user("generated-template-no-access@example.com")

    get "/admin/root"

    assert_response :forbidden
  end

  test "the generated admin root lists sections and filters a search" do
    sign_in_admin("generated-template-admin@example.com")

    get "/admin/root", params: { anchor_url: "javascript:alert(1)" }

    assert_response :success
    assert_includes response.body, "Manage and monitor your application"
    assert_includes response.body, 'href="/admin/sections/admin_activity_logs?anchor_url=%2Fadmin"'

    get "/admin/root", params: { anchor_url: "/", q: "zzzz-no-match" }

    assert_response :success
    assert_includes response.body, "No admin screens or sections match that search."
    assert_includes response.body, "anchor_url"

    get "/admin/root",
        params: { q: "admin" },
        headers: { "Turbo-Frame" => Admin::RootController::SEARCH_RESULTS_FRAME_ID }

    assert_response :success
    assert_includes response.body, Admin::RootController::SEARCH_RESULTS_FRAME_ID
    refute_includes response.body, "Manage and monitor your application"
  end

  test "the generated audit log records the actor, the record, and the root" do
    actor = sign_in_admin("generated-template-auditor@example.com")
    recording = admin_root_recording
    plain = Object.new
    rootless = Struct.new(:root_recording_id, :id).new(nil, recording.id)
    nameless = Struct.new(:id).new(recording.id)

    recorded = AdminAuditLog.record_admin_action!(audit_event(actor: actor, record: actor, access_recording: recording))

    assert_equal "User", recorded.actor_type
    assert_equal actor.id.to_s, recorded.actor_id
    assert_equal actor.id.to_s, recorded.record_id
    assert_equal recording.id, recorded.root_recording_id
    assert_nil AdminAuditLog.record_type_for(nil)
    assert_nil AdminAuditLog.record_id_for(nil)
    assert_equal plain.to_s, AdminAuditLog.record_id_for(plain)
    assert_nil AdminAuditLog.root_recording_id_for(nil)
    assert_equal recording.id, AdminAuditLog.root_recording_id_for(rootless)
    assert_nil AdminAuditLog.root_recording_id_for(nameless)
  ensure
    AdminAuditLog.where(request_id: "generated-template").delete_all
  end

  test "the generated install file sets the mount path, the actor, and an empty access resolver" do
    config = RecordingStudioAdmin.configuration
    previous_mount = config.default_mount_path
    previous_resolver = config.access_recording_resolver

    load TEMPLATE_ROOT.join("install/templates/recording_studio_admin_initializer.rb").to_s

    assert_equal "__MOUNT_PATH__", config.default_mount_path
    assert_equal :authenticate_user!, config.authentication_method
    assert_equal :current_user, config.current_actor_method
    assert_nil config.access_recording_resolver.call(nil)
  ensure
    config.default_mount_path = previous_mount
    config.access_recording_resolver = previous_resolver
    config.authentication_method = @previous_authentication_method
    config.current_actor_method = @previous_actor_method
  end

  test "the generated migrations create the admin tables and can add then remove the root column" do
    connection = ActiveRecord::Base.connection
    previous_search_path = connection.schema_search_path
    connection.execute("CREATE SCHEMA #{SCHEMA}")
    connection.schema_search_path = "#{SCHEMA}, public"
    connection.schema_cache.clear!

    load ADMIN_ROOT_TEMPLATES.join("db/migrate/create_admin_roots.rb").to_s
    load ADMIN_ROOT_TEMPLATES.join("db/migrate/create_admin_audit_logs.rb").to_s
    load TEMPLATE_ROOT.join("logs/templates/db/migrate/add_root_recording_id_to_admin_audit_logs.rb").to_s

    run_migration(CreateAdminRoots, connection, :up)
    run_migration(CreateAdminAuditLogs, connection, :up)
    assert connection.table_exists?(:admin_roots)
    assert_equal "Admin", connection.columns(:admin_roots).find { |column| column.name == "name" }.default

    connection.remove_index :admin_audit_logs, name: "index_admin_audit_logs_on_root_and_occurred_at"
    run_migration(AddRootRecordingIdToAdminAuditLogs, connection, :up)
    assert connection.index_exists?(
      :admin_audit_logs,
      %i[root_recording_id occurred_at],
      name: "index_admin_audit_logs_on_root_and_occurred_at"
    )

    run_migration(AddRootRecordingIdToAdminAuditLogs, connection, :up)
    run_migration(AddRootRecordingIdToAdminAuditLogs, connection, :down)
    refute connection.column_exists?(:admin_audit_logs, :root_recording_id)
  ensure
    connection.schema_search_path = previous_search_path if previous_search_path
    connection.execute("DROP SCHEMA IF EXISTS #{SCHEMA} CASCADE")
    connection.schema_cache.clear!
  end

  private

  def sign_in_user(email)
    user = User.find_or_create_by!(email: email) do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user
    user
  end

  def sign_in_admin(email)
    user = sign_in_user(email)
    grant_admin_access_for_test!(recording: admin_root_recording, actor: user)
    user
  end

  def admin_root_recording
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end

  def audit_event(actor:, record:, access_recording:)
    RecordingStudioAdmin::AdminActionAuditEvent.new(
      id: SecureRandom.uuid,
      resource_key: "users",
      action_key: "remove",
      outcome: "performed",
      actor: actor,
      record: record,
      access_recording: access_recording,
      surface_key: "admin",
      http_method: "DELETE",
      destructive: true,
      required_role: "admin",
      blast_radius: "record",
      request_id: "generated-template",
      ip_address: "127.0.0.1",
      user_agent: "test",
      metadata: {},
      error_class: nil,
      error_message: nil,
      recording_studio_event: nil
    )
  end

  def run_migration(migration_class, connection, direction)
    migration = migration_class.new
    migration.verbose = false
    migration.exec_migration(connection, direction)
  end
end
