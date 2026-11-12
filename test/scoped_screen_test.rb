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
    filter :scope, label: "Reach"
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

  def test_scopeable_declares_scope_and_recordable_type_filters
    assert_equal %w[PressKit Image], LibraryScreen.scopeable_recordable_types
    assert_predicate LibraryScreen, :scopeable?
    assert_equal %i[scope recordable_type], LibraryScreen.filters.map(&:key)
    assert_equal :reach, LibraryScreen.filters.first.param_key
    assert_equal "Reach", LibraryScreen.filters.first.label_text

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

  def test_scope_choice_ignores_unknown_values_and_other_ids
    choice = RecordingStudioAdmin::RecordingScope.choice(
      {
        "scope" => "site",
        "reach" => "site",
        "recordable_type" => "Workspace",
        "recording_id" => "other-root",
        "root_recording_id" => "sibling"
      },
      allowed_types: %w[PressKit Image]
    )

    assert_equal "self", choice[:mode]
    assert_nil choice[:recordable_type]
    assert_equal "subtree", RecordingStudioAdmin::RecordingScope.mode_from("subtree")
    assert_equal "Image", RecordingStudioAdmin::RecordingScope.type_from("Image", %w[PressKit Image])
  end

  def test_scoped_screen_path_adds_scope_and_recordable_type
    routes = Object.new
    routes.define_singleton_method(:screen_path) { |key| "/stats/screens/#{key}" }
    context = RecordingStudioAdmin::Context.new(routes: routes)

    path = context.scoped_screen_path("library", scope: :subtree, recordable_type: "Page")
    query = Rack::Utils.parse_query(URI.parse(path).query)

    assert_equal "/stats/screens/library", URI.parse(path).path
    assert_equal "subtree", query["reach"]
    assert_equal "Page", query["recordable_type"]
  end

  def test_choice_labels_keep_custom_text_and_humanize_plain_values
    definition = RecordingStudioAdmin::Definitions::FilterDefinition
    custom = { value: "subtree", label: "Everything under it" }

    assert_equal "Everything under it", definition.choice_label(custom)
    assert_equal "subtree", definition.choice_value(custom)
    assert_equal "Group by", definition.choice_label("group_by")
  end
end
