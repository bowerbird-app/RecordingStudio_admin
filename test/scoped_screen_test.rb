# frozen_string_literal: true

require "test_helper"

class ScopedScreenTest < Minitest::Test
  class PlainScreen < RecordingStudioAdmin::Screen
    key "plain_screen"
    title "Plain"
    query { |_context| :untouched }
  end

  class LibraryScreen < RecordingStudioAdmin::Screen
    key "library_screen"
    title "Library"
    scopeable recordable_types: %w[PressKit Image]
    filter :recordable_type, label: :"recording_studio.admin.screens.filters.trigger_label"
  end

  def test_label_uses_the_given_string_and_humanizes_when_missing
    labeled = RecordingStudioAdmin::Definitions::FilterDefinition.new(:person, :select, label: "Who")
    plain = RecordingStudioAdmin::Definitions::FilterDefinition.new(:person, :select, {})

    assert_equal "Who", labeled.label_text
    assert_equal "Person", plain.label_text
  end

  def test_label_translates_a_key_and_a_callable
    I18n.backend.store_translations(:en, recording_studio_admin_scope_test: { who: "Which person" })
    keyed = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :person,
      :select,
      label: "recording_studio_admin_scope_test.who"
    )
    callable = RecordingStudioAdmin::Definitions::FilterDefinition.new(
      :person,
      :select,
      label: ->(context) { context.params[:who] }
    )
    context = RecordingStudioAdmin::Context.new(params: { who: "Ada" })

    assert_equal "Which person", keyed.label_text(context)
    assert_equal "Ada", callable.label_text(context)
    assert_equal "Person", callable.label_text(nil)
  end

  def test_scopeable_declares_a_recordable_type_filter
    assert_equal %w[PressKit Image], LibraryScreen.scopeable_recordable_types
    assert_predicate LibraryScreen, :scopeable?
    assert_equal %i[recordable_type], LibraryScreen.filters.map(&:key)
    assert_equal :recordable_type, LibraryScreen.filters.first.param_key
    assert_equal :"recording_studio.admin.screens.filters.trigger_label", LibraryScreen.filters.first.options[:label]

    refute_predicate PlainScreen, :scopeable?
    assert_empty PlainScreen.filters
  end

  def test_scopeable_accepts_classes_and_rejects_unknown_shapes
    press_kit = Class.new
    press_kit.define_singleton_method(:name) { "PressKit" }
    screen = Class.new(RecordingStudioAdmin::Screen)
    screen.scopeable recordable_types: [press_kit, "Image"]

    assert_equal %w[PressKit Image], screen.scopeable_recordable_types

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Screen).scopeable recordable_types: ["folder;drop"]
    end
    assert_includes error.message, "folder;drop"
  end

  def test_type_from_ignores_unknown_values
    allowed = %w[PressKit Image]

    assert_nil RecordingStudioAdmin::RecordingScope.type_from("Workspace", allowed)
    assert_nil RecordingStudioAdmin::RecordingScope.type_from(["Image"], allowed)
    assert_equal "Image", RecordingStudioAdmin::RecordingScope.type_from("Image", allowed)
  end

  def test_scoped_screen_path_adds_recordable_type_and_drops_scope
    routes = Object.new
    routes.define_singleton_method(:screen_path) { |key| "/stats/screens/#{key}" }
    context = RecordingStudioAdmin::Context.new(routes: routes)

    path = context.scoped_screen_path("library", scope: :subtree, reach: "subtree", recordable_type: "Page")
    query = Rack::Utils.parse_query(URI.parse(path).query)

    assert_equal "/stats/screens/library", URI.parse(path).path
    assert_nil query["scope"]
    assert_nil query["reach"]
    assert_equal "Page", query["recordable_type"]
  end

  def test_within_filter_rejects_a_bad_type_and_a_reserved_param
    screen = Class.new(RecordingStudioAdmin::Screen)
    screen.scopeable recordable_types: %w[PressKit Image]
    screen.filter :press_kit, type: :within, label: "Press kit", recordable_type: "PressKit"

    assert_equal "PressKit", screen.filters.last.options[:recordable_type]
    assert_equal [{ value: "", label: "All press kits" }], screen.filters.last.present_entries(nil)

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Screen).filter :folder, type: :within, recordable_type: "folder"
    end
    assert_includes error.message, "folder"

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Screen).filter :folder, type: :within, recordable_type: "Folder", param: :scope
    end
    assert_includes error.message, "scope"

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      Class.new(RecordingStudioAdmin::Screen).filter :reach, type: :within, recordable_type: "Folder"
    end
    assert_includes error.message, "reach"

    error = assert_raises(RecordingStudioAdmin::InvalidDefinition) do
      named = Class.new(RecordingStudioAdmin::Screen)
      named.filter :image, type: :within, recordable_type: "Image"
      named.scopeable recordable_types: %w[PressKit]
    end
    assert_includes error.message, "Image"
  end

  def test_within_all_label_and_name_callables
    labeled = Class.new(RecordingStudioAdmin::Screen)
    labeled.filter :press_kit, type: :within, label: "Press kit", recordable_type: "PressKit",
                               all_label: "Every kit",
                               name: ->(recording) { recording.recordable.name }
    definition = labeled.filters.first
    assert_equal "Every kit", definition.present_entries(nil).first[:label]

    context = RecordingStudioAdmin::Context.new(params: { suffix: "ada" })
    catalog = RecordingStudioAdmin::WithinCatalog.new(context, definition)
    recordable = Struct.new(:name, :title).new("  ", "Kit")
    recording = Struct.new(:id, :recordable).new("rec-1", recordable)

    assert_equal "Kit", catalog.display_name(recording)

    fixed = Class.new(RecordingStudioAdmin::Screen)
    fixed.filter :press_kit, type: :within, recordable_type: "PressKit",
                             name: -> { "Fixed" },
                             all_label: -> { "Every one" }
    fixed_catalog = RecordingStudioAdmin::WithinCatalog.new(context, fixed.filters.first)
    assert_equal "Every one", fixed.filters.first.present_entries(nil).first[:label]
    assert_equal "Fixed", fixed_catalog.display_name(recording)

    paired = Class.new(RecordingStudioAdmin::Screen)
    paired.filter :press_kit, type: :within, recordable_type: "PressKit",
                              name: ->(item, ctx) { "#{item.id}-#{ctx.params[:suffix]}" },
                              all_label: ->(ctx) { ctx.params[:suffix] }
    paired_definition = paired.filters.first
    paired_catalog = RecordingStudioAdmin::WithinCatalog.new(context, paired_definition)
    assert_equal "ada", paired_definition.present_entries(context).first[:label]
    assert_equal "rec-1-ada", paired_catalog.display_name(recording)

    blank = Class.new(RecordingStudioAdmin::Screen)
    blank.filter :folder, type: :within, label: "Folder", recordable_type: "Folder", name: -> { " " }
    blank_catalog = RecordingStudioAdmin::WithinCatalog.new(context, blank.filters.first)
    untitled = Struct.new(:id, :recordable).new(9, Struct.new(:name, :title).new("", nil))
    assert_equal "9", blank_catalog.display_name(untitled)
    assert_equal "All folders", blank.filters.first.present_entries(nil).first[:label]
  end

  def test_choice_labels_keep_custom_text_and_humanize_plain_values
    definition = RecordingStudioAdmin::Definitions::FilterDefinition
    custom = { value: "folder", label: "Field notes" }

    assert_equal "Field notes", definition.choice_label(custom)
    assert_equal "folder", definition.choice_value(custom)
    assert_equal "Group by", definition.choice_label("group_by")
  end
end
