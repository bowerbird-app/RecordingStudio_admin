# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"
require_relative "test_helper"
require_relative "dummy/config/environment"

require "rails/test_help"

class RecordingStudioV3Test < ActiveSupport::TestCase
  include DummyAccessTestHelpers

  test "dummy recordable declarations validate and expose v3 introspection" do
    assert RecordingStudio.validate_recordable_declarations!
    assert_equal %w[AdminRoot Workspace], RecordingStudio.root_recordable_types.sort
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for("Folder")
    assert_equal %w[Workspace Folder], RecordingStudio.allowed_parent_types_for(Page)
  end

  test "root recordable creates a root recording" do
    workspace = Workspace.create!(name: unique_name("Root Workspace"))

    root_recording = RecordingStudio.root_recording_for(workspace)

    assert_predicate root_recording, :persisted?
    assert_equal workspace, root_recording.recordable
    assert_nil root_recording.parent_recording_id
    assert_equal root_recording.id, root_recording.root_recording_id
  end

  test "allowed child can be recorded under a workspace root" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Child Workspace")))
    folder = Folder.new(name: unique_name("Allowed Folder"))

    event = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording
    )

    assert_equal folder, event.recording.recordable
    assert_equal root_recording, event.recording.parent_recording
  end

  test "page can be recorded under allowed workspace and folder parents" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Page Workspace")))
    folder_recording = record_child(Folder.new(name: unique_name("Page Folder")), root_recording, root_recording)

    workspace_page_recording = record_child(
      Page.new(title: unique_name("Workspace Page")),
      root_recording,
      root_recording
    )
    folder_page_recording = record_child(Page.new(title: unique_name("Folder Page")), root_recording, folder_recording)

    assert_equal root_recording, workspace_page_recording.parent_recording
    assert_equal folder_recording, folder_page_recording.parent_recording
  end

  test "child recordable cannot be created as a root" do
    folder = Folder.create!(name: unique_name("Root Rejected Folder"))

    assert_raises(RecordingStudio::RootNotAllowed) do
      RecordingStudio.root_recording_for(folder)
    end
  end

  test "parentless child under an existing root is invalid" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Parentless Workspace")))
    folder = Folder.create!(name: unique_name("Parentless Folder"))
    recording = RecordingStudio::Recording.new(root_recording: root_recording, recordable: folder)

    assert_not recording.valid?
    assert_includes recording.errors[:parent_recording_id].join, "cannot be blank"
  end

  test "page cannot be recorded under another page" do
    root_recording = RecordingStudio.root_recording_for(Workspace.create!(name: unique_name("Invalid Page Workspace")))
    page_recording = record_child(Page.new(title: unique_name("Parent Page")), root_recording, root_recording)

    error = assert_raises(RecordingStudio::InvalidParent) do
      record_child(Page.new(title: unique_name("Nested Page")), root_recording, page_recording)
    end
    assert_equal "Page cannot be recorded under Page", error.message
  end

  test "backed admin section resolves a reusable child recording" do
    section_key = "backed_#{SecureRandom.hex(4)}"
    workspace_name = unique_name("Section Parent Workspace")
    folder_name = unique_name("Section Folder")
    original_registry = RecordingStudioAdmin.instance_variable_get(:@registry)
    original_access_recording_resolver = RecordingStudioAdmin.configuration.access_recording_resolver
    original_workspace_sections_definition = Workspace.instance_variable_get(
      :@recording_studio_admin_sections_definition
    )
    parent_workspace = Workspace.find_or_create_by!(name: workspace_name)
    parent_recording = RecordingStudio.root_recording_for(parent_workspace)
    actor = User.find_or_create_by!(email: "backed-section-#{SecureRandom.hex(4)}@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    grant_admin_access_for_test!(recording: parent_recording, actor: actor)

    Workspace.recording_studio_admin_sections do
      section :stats
      section section_key.to_sym
    end

    section_class = Class.new(RecordingStudioAdmin::Section) do
      key section_key
      title "Backed section"
      recordable "Folder",
                 find_or_create_by: -> { { name: folder_name } },
                 parent: -> { Workspace.find_or_create_by!(name: workspace_name) }
    end

    RecordingStudioAdmin.instance_variable_set(:@registry, RecordingStudioAdmin::Registry.new)
    RecordingStudioAdmin.configuration.access_recording_resolver = nil
    RecordingStudioAdmin.register_section(section_class)

    context = RecordingStudioAdmin::Context.new(
      current_actor: actor,
      controller: Class.new do
        define_method(:recording_studio_admin_access_recording) { parent_recording }
      end.new
    )

    first_result = RecordingStudioAdmin.resolve_section(key: section_key, context: context)
    second_result = RecordingStudioAdmin.resolve_section(key: section_key, context: context)

    assert_equal folder_name, first_result.recordable.name
    assert_equal first_result.recording, second_result.recording
    assert_equal parent_recording, first_result.recording.root_recording
    assert_equal parent_recording, first_result.recording.parent_recording
    assert_equal 1, RecordingStudio::Recording.where(recordable: first_result.recordable, trashed_at: nil).count
  ensure
    Workspace.instance_variable_set(
      :@recording_studio_admin_sections_definition,
      original_workspace_sections_definition
    )
    RecordingStudioAdmin.configuration.access_recording_resolver = original_access_recording_resolver
    RecordingStudioAdmin.instance_variable_set(:@registry, original_registry)
  end

  private

  def record_child(recordable, root_recording, parent_recording)
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording
    ).recording
  end

  def unique_name(prefix)
    "#{prefix} #{SecureRandom.hex(4)}"
  end
end
