# frozen_string_literal: true

require "test_helper"

class BlastRadiusTest < Minitest::Test
  Row = Struct.new(:name)
  Recording = Struct.new(:recordable, :parent_recording, keyword_init: true)

  class SiteScreen < RecordingStudioAdmin::Screen
    key "blast_site"
    title "Site reports"
    blast_radius :site
    query { |_context| [] }
  end

  class RecordingScreen < RecordingStudioAdmin::Screen
    key "blast_recording"
    title "Recording reports"
    query { |_context| [Row.new("first")] }

    table do
      column :name
      action :site_action,
             text: "Site action",
             url: "/admin/site-action",
             blast_radius: :site
    end
  end

  class SiteWidgetScreen < RecordingStudioAdmin::Screen
    key "blast_widget_screen"
    title "Widget reports"
    blast_radius :site
    query { |_context| [] }

    widget :site_total do
      blast_radius :site
      title "Site total"
      value 1
    end
  end

  class SiteSection < RecordingStudioAdmin::Section
    key "blast_site_section"
    title "Site section"
    blast_radius :site
    link :site, text: "Site reports", url: ->(context) { context.admin_screen_path("blast_site") }
  end

  class RecordingSection < RecordingStudioAdmin::Section
    key "blast_recording_section"
    title "Recording section"
    widget "blast_widget_screen.widgets.site_total"
  end

  class SiteResource < RecordingStudioAdmin::Resource
    key "blast_site_users"
    section "blast_site_section"
    title "Site users"
    blast_radius :site

    action :flag,
           text: "Flag",
           url: "/admin/users/1/flag",
           method: :post,
           blast_radius: :site
  end

  class RecordingResourceWithSiteAction < RecordingStudioAdmin::Resource
    key "blast_recording_users"
    section "blast_recording_section"
    title "Recording users"

    action :flag,
           text: "Flag",
           url: "/admin/recording-users/1/flag",
           method: :post,
           blast_radius: :site
  end

  def setup
    @original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    @original_configuration = RecordingStudioAdmin.instance_variable_get(:@configuration)
    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.instance_variable_set(:@configuration, RecordingStudioAdmin::Configuration.new)

    @site_recording = Recording.new(recordable: :admin_root, parent_recording: nil)
    @workspace_recording = Recording.new(recordable: :workspace, parent_recording: @site_recording)

    RecordingStudioAdmin.configuration.site_admin_recording_resolver = ->(_context) { @site_recording }
    RecordingStudioAdmin.register_screen(SiteScreen)
    RecordingStudioAdmin.register_screen(RecordingScreen)
    RecordingStudioAdmin.register_screen(SiteWidgetScreen)
    RecordingStudioAdmin.register_section(SiteSection)
    RecordingStudioAdmin.register_section(RecordingSection)
    RecordingStudioAdmin.register_resource(SiteResource)
    RecordingStudioAdmin.register_resource(RecordingResourceWithSiteAction)
  end

  def teardown
    RecordingStudioAdmin.instance_variable_set(:@registry, @original_registry)
    RecordingStudioAdmin.instance_variable_set(:@configuration, @original_configuration)
  end

  def test_site_screen_requires_configured_site_admin_recording
    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        RecordingStudioAdmin.resolve_screen(key: "blast_site", context: context_for(@workspace_recording))
      end
    end

    assert_includes error.message, "blast_radius :site"

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      screen = RecordingStudioAdmin.resolve_screen(key: "blast_site", context: context_for(@site_recording))
      assert_equal "blast_site", screen.key
    end
  end

  def test_site_resource_action_requires_site_admin_recording
    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        RecordingStudioAdmin.resolve_resource_action(
          key: "blast_site_users",
          action: :flag,
          context: context_for(@workspace_recording),
          record: Row.new("first")
        )
      end
    end

    assert_includes error.message, "Section \"blast_site_section\""
    assert_includes error.message, "blast_radius :site"

    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      action = RecordingStudioAdmin.resolve_resource_action(
        key: "blast_site_users",
        action: :flag,
        context: context_for(@site_recording),
        record: Row.new("first")
      )
      assert_equal "Flag", action.resolve(Row.new("first"), context_for(@site_recording)).text
    end
  end

  def test_site_resource_action_is_rejected_in_recording_scoped_resource
    error = assert_raises(RecordingStudioAdmin::AuthorizationFailed) do
      with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
        RecordingStudioAdmin.resolve_resource_action(
          key: "blast_recording_users",
          action: :flag,
          context: context_for(@workspace_recording),
          record: Row.new("first")
        )
      end
    end

    assert_includes error.message, "Resource blast_recording_users.flag"
    assert_includes error.message, "blast_radius :site"
  end

  def test_site_table_action_is_filtered_from_recording_scoped_screen
    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      screen = RecordingStudioAdmin.resolve_screen(key: "blast_recording", context: context_for(@workspace_recording))
      assert_empty screen.table.actions
    end
  end

  def test_site_widget_is_filtered_from_recording_scoped_section
    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      section = RecordingStudioAdmin.resolve_section(key: "blast_recording_section",
                                                     context: context_for(@workspace_recording))
      assert_empty section.widgets
    end
  end

  def test_available_items_omit_site_definitions_outside_site_admin_recording
    with_singleton_stub(RecordingStudioAccessible, :authorized?, true) do
      recording_items = RecordingStudioAdmin.available_admin_items(
        context: context_for(@workspace_recording),
        recording: @workspace_recording
      )
      site_items = RecordingStudioAdmin.available_admin_items(
        context: context_for(@site_recording),
        recording: @site_recording
      )

      refute_includes recording_items.map(&:key), "blast_site_section"
      assert_includes site_items.map(&:key), "blast_site_section"
    end
  end

  def test_unknown_blast_radius_raises_invalid_definition
    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Screen) do
        key "bad_blast_radius"
        blast_radius :planet
      end
    end

    assert_includes error.message, "unsupported blast_radius :planet"
  end

  private

  def context_for(recording)
    controller = Class.new do
      define_method(:recording_studio_admin_access_recording) { recording }
    end.new

    RecordingStudioAdmin::Context.new(current_actor: :actor, controller: controller)
  end
end
