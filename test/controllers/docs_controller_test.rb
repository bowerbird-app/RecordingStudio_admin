# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "../test_helper"
require_relative "../dummy/config/environment"

require "devise/test/integration_helpers"
require "rails/test_help"

class DocsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  TEST_PASSWORD = "DocsTestPassword!2026"

  setup do
    @user = User.find_or_create_by!(email: "docs-test@example.com") do |user|
      user.password = TEST_PASSWORD
      user.password_confirmation = TEST_PASSWORD
    end

    workspace = Workspace.find_or_create_by!(name: "Docs Test Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: @user)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_admin_access_for_test!(recording: RecordingStudio.root_recording_for(admin_root), actor: @user)

    sign_in @user
  end

  test "install page renders successfully" do
    get docs_install_path
    assert_response :success
    assert_select "h1", text: "Install"
    assert_includes response.body, "Step 1"
    assert_includes response.body, "Run the install generator (required)"
    assert_includes response.body, "bin/rails generate recording_studio_admin:install"
    assert_includes response.body, "RecordingStudioAdmin.configure do |config|"
    assert_includes response.body, "/admin/sections/:key"
    assert_includes response.body, "admin_activity_logs"
    assert_includes response.body, "AdminAuditLog"
  end

  test "admin access page renders successfully" do
    get docs_admin_access_path

    assert_response :success
    assert_select "h1", text: "Admin access"
    assert_includes response.body, "RecordingStudioAccessible.authorized?"
    assert_includes response.body, "config.access_recording_resolver"
    assert_includes response.body, "class AdminRoot"
    assert_includes response.body, "class AdminSection"
    assert_includes response.body, "available_admin_sections"
    assert_includes response.body, "available_admin_items"
  end

  test "admin root page renders successfully" do
    get docs_admin_root_path
    response_text = response.body.downcase

    assert_response :success
    assert_select "h1", text: "Admin root"
    assert_includes response_text, "adminroot is a convenience recordable"
    assert_includes response_text, "it is not a privileged engine-only type"
    assert_includes response_text, "what the generator adds"
    assert_includes response.body, "recording_studio_admin_context.available_admin_sections"
    assert_includes response.body, "recording_studio_admin_context.available_admin_items"
    assert_includes response.body, "recording_studio_admin_access_recording"
  end

  test "admin section page renders successfully" do
    get docs_admin_section_path
    response_text = response.body.downcase

    assert_response :success
    assert_select "h1", text: "Admin section"
    assert_includes response_text, "sections are admin landing pages"
    assert_includes response_text, "class userssection"
    assert_includes response_text, "recordingstudioadmin::section"
    assert_includes response_text, "widgets.api_requests.api_activity"
    assert_includes response.body, "recording_studio_admin_sections"
    assert_includes response_text, "recordable"
    assert_includes response_text, "adminsection"
  end

  test "config page renders successfully" do
    get docs_config_path
    assert_response :success
    assert_select "h1", text: "Config"
    assert_includes response.body, "RecordingStudioAdmin.configure do |config|"
    assert_includes response.body, "config.required_access_role = :view"
    assert_includes response.body, "config.admin_sections_resolver"
    assert_includes response.body, "Rails.application.config.to_prepare do"
    assert_includes response.body, "RecordingStudioAdmin::AllowsAdminSections"
  end

  test "recordable types page renders configured recordables dynamically" do
    create_recordable_type_summary_data

    get docs_recordable_types_path
    response_text = response.body.gsub(/\s+/, " ").strip

    assert_response :success
    assert_select "h1", text: "Recordable types"
    assert_includes(
      response.body,
      "The table below comes from RecordingStudio.recordable_declarations and v3 parent/root introspection."
    )
    assert_select "table", minimum: 1
    assert_includes response.body, "Workspace"
    assert_includes response.body, "Folder"
    assert_includes response_text, "Role"
    assert_includes response_text, "Child"
    assert_includes response_text, "Workspace, Folder"
    assert_includes response_text, "Dummy app"
  end

  test "recordable types page includes dummy app defaults" do
    get docs_recordable_types_path

    assert_response :success
    assert_includes response.body, "Workspace"
    assert_includes response.body, "Folder"
  end

  test "recordings tree page renders successfully" do
    workspace = Workspace.create!(name: "Tree Workspace")
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.create!(name: "Reference")
    folder_recording = record_child(folder, root_recording, root_recording)
    page = Page.create!(title: "API")
    record_child(page, root_recording, folder_recording)

    get docs_recordings_tree_path

    assert_response :success
    assert_select "h1", text: "Recordings tree"
    assert_includes response.body, "Workspace: Tree Workspace"
    assert_includes response.body, "Folder: Reference"
    assert_includes response.body, "Page: API"
    refute_includes response.body, "Access boundary"
    assert_includes response.body, "Access: Admin"
    assert_select "div[role='tree']", count: 1
    assert_select "[role='treeitem']", minimum: 3
    refute_includes response.body, "Current structure"
    refute_includes response.body, "This tree is generated from RecordingStudio::Recording records"
  end

  test "recordings tree page tolerates legacy recordable types with missing constants" do
    RecordingStudio::Recording.insert_all!(
      [
        {
          recordable_type: "LegacyAdminSection",
          recordable_id: SecureRandom.uuid,
          created_at: Time.current,
          updated_at: Time.current
        }
      ]
    )

    get docs_recordings_tree_path

    assert_response :success
    assert_includes response.body, "Legacy admin section: Missing recordable class"
    assert_select "div[role='tree']", count: 1
  end

  test "gem_views page renders successfully" do
    get docs_gem_views_path
    assert_response :success
    assert_select "h1", text: "Gem Views"
    assert_select "table", minimum: 1
    refute_includes response.body, "app/views/recording_studio_admin/home/index.html.erb"
  end

  test "methods page renders successfully" do
    get docs_methods_path
    assert_response :success
    assert_select "h1", text: "Methods"
    assert_includes response.body, "RecordingStudioAdmin.register_screen"
    assert_includes response.body, "RecordingStudioAdmin.section_for"
    assert_includes response.body, "RecordingStudioAdmin.resolve_screen"
    assert_includes response.body, "RecordingStudioAdmin.available_admin_items"
    assert_includes response.body, "RecordingStudioAdmin.enabled_admin_section_keys"
  end

  test "helpers page renders successfully" do
    get docs_helpers_path

    assert_response :success
    assert_select "h1", text: "Helpers"
    assert_includes response.body, "recording_studio_admin_context.available_admin_sections"
    assert_includes response.body, "recording_studio_admin_context.available_admin_items"
    assert_includes response.body, "context.widget_period_label"
    assert_includes response.body, "context.widget_time_range"
    assert_includes response.body, "context.widget_filter_params"
    assert_includes response.body, "preserve_anchor_url"
    assert_includes response.body, "page_nav_anchor_url"
    assert_includes response.body, "widget_link_url"
  end

  test "blast radius page renders successfully" do
    get docs_blast_radius_path

    assert_response :success
    assert_select "h1", text: "Blast radius"
    assert_includes response.body, "blast_radius :site"
    assert_includes response.body, "config.site_admin_recording_resolver"
    assert_includes response.body, "Nested guardrails"
    assert_includes response.body, "RecordingStudioAccessible.authorized?"
  end

  test "generators page renders successfully" do
    switch_to_root!(RecordingStudio.root_recording_for(AdminRoot.find_or_create_by!(name: "Admin")))

    get admin_generators_path

    assert_response :success
    assert_select "h1", text: "Generators"
    assert_includes response.body, "recording_studio_admin:install"
    assert_includes response.body, "recording_studio_admin:admin_root"
    assert_includes response.body, "bin/rails generate recording_studio_admin:install"
    assert_includes response.body, "bin/rails generate recording_studio_admin:admin_root"
    assert_includes response.body, "Routes"
    assert_includes response.body, "Generated files"
    assert_includes response.body, "config/initializers/recording_studio_admin.rb"
    assert_includes response.body, "app/views/admin/root/show.html.erb"
    assert_includes response.body, "app/models/admin_audit_log.rb"
    assert_includes response.body, "create_admin_audit_logs"
    assert_select "div.fp-section-title-anchor", minimum: 2
  end

  test "sidebar links match mounted surfaces and docs destinations" do
    get docs_install_path

    assert_select %(a[href="#{root_path}"]), text: /Workspace home/
    assert_select %(a[href="#{admin_root_path}"]), text: /Admin root page/
    assert_select 'a[href="/admin"]', text: /Mounted admin/
    assert_select %(a[href="#{stats_root_path}"]), text: /Stats root/
    assert_select %(a[href="#{docs_install_path}"]), text: /Install guide/
    assert_select %(a[href="#{docs_admin_access_path}"]), text: /Access flow/
    assert_select %(a[href="#{docs_admin_root_path}"]), text: /AdminRoot recordable/
    assert_select %(a[href="#{docs_admin_section_path}"]), text: /Admin sections/
    assert_select %(a[href="#{docs_config_path}"]), text: /Configuration/
    assert_select %(a[href="#{docs_recordable_types_path}"]), text: /Recordable types/
    assert_select %(a[href="#{docs_recordings_tree_path}"]), text: /Recordings tree/
    assert_select %(a[href="#{docs_gem_views_path}"]), text: /Engine views/
    assert_select %(a[href="#{docs_methods_path}"]), text: /Public API/
    assert_select %(a[href="#{docs_helpers_path}"]), text: /View helpers/
    assert_select %(a[href="#{docs_blast_radius_path}"]), text: /Blast radius/
    assert_select %(a[href="#{admin_generators_path}"]), text: /Generators/
  end

  private

  def create_recordable_type_summary_data
    workspace_recordings_before = RecordingStudio::Recording.where(recordable_type: "Workspace").count
    workspaces_before = Workspace.count
    folder_recordings_before = RecordingStudio::Recording.where(recordable_type: "Folder").count
    folders_before = Folder.count

    workspace = Workspace.create!(name: "Counted Workspace")
    2.times do
      RecordingStudio.root_recording_for(Workspace.create!(name: "Counted Workspace #{SecureRandom.hex(4)}"))
    end

    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.create!(name: "Counted Folder")
    record_child(folder, root_recording, root_recording)

    {
      workspace: recordable_type_summary(
        workspace_recordings_before + 3,
        workspaces_before + 3,
        "recordings",
        "recordables"
      ),
      folder: recordable_type_summary(
        folder_recordings_before + 1,
        folders_before + 1,
        "recording",
        "recordable"
      )
    }
  end

  def recordable_type_summary(recording_count, recordable_count, _recording_label, _recordable_label)
    "#{recording_count} #{'recording'.pluralize(recording_count)} #{recordable_count} " \
      "#{'recordable'.pluralize(recordable_count)}"
  end

  def switch_to_root!(root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: root_recording.id,
        return_to: "/"
      }
    }
    follow_redirect!
  end

  def record_child(recordable, root_recording, parent_recording)
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording
    ).recording
  end
end
