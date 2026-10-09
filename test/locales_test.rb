# frozen_string_literal: true

require "test_helper"
require "yaml"
require "tmpdir"

class LocalesTest < Minitest::Test
  # I18n template tokens use %{name}; RuboCop prefers %<name>s for Kernel#sprintf.
  # rubocop:disable Style/FormatStringToken
  EXPECTED_KEYS = {
    "navigation.go_back" => "Go back",
    "navigation.close" => "Close",
    "sections.index.title" => "Admin sections",
    "sections.index.subtitle" => "Browse the sections available in this admin context",
    "sections.index.search_placeholder" => "Search screens and sections",
    "sections.index.filter_all" => "All",
    "sections.index.filter_sections" => "Sections",
    "sections.index.filter_screens" => "Screens",
    "sections.index.badge_screen" => "Screen",
    "sections.index.badge_section" => "Section",
    "sections.index.empty_search" => "No admin screens or sections match that search.",
    "sections.index.empty" => "No admin sections are available.",
    "sections.show.more" => "More",
    "screens.filters.trigger_label" => "Filters",
    "screens.filters.all_placeholder" => "All",
    "screens.table.counting_rows" => "Counting rows...",
    "screens.table.export" => "Export",
    "screens.table.export_restricted" => "Export restricted",
    "screens.table.columns" => "Columns",
    "screens.table.choose_columns" => "Choose table columns",
    "screens.table.columns_modal_title" => "Table columns",
    "screens.table.reset" => "Reset",
    "screens.table.apply" => "Apply",
    "screens.table.actions" => "Actions",
    "screens.table.actions_for_email" => "Actions for %{email}",
    "screens.table.actions_for_row" => "Actions for row %{id}",
    "screens.table.row_actions" => "Row actions",
    "screens.table.end" => "End",
    "widgets.more" => "More",
    "widgets.more_info_about" => "More information about %{title}",
    "widgets.more_info_about_widget" => "More information about this widget",
    "widgets.open" => "Open %{label}"
  }.freeze
  # rubocop:enable Style/FormatStringToken

  def setup
    @locale_path = File.expand_path("../config/locales/en.yml", __dir__)
    @original_load_path = I18n.load_path.dup
    ensure_gem_locale_loaded!
  end

  def teardown
    I18n.load_path = @original_load_path
    I18n.reload!
  end

  def test_engine_ships_only_english_locale_files
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  def test_engine_exposes_locales_path_and_rails_loads_english_file
    locale_path = File.join(engine_locales_dir, "en.yml")

    assert File.exist?(locale_path)
    assert_includes RecordingStudioAdmin::Engine.paths["config/locales"].existent.map { |path|
      File.expand_path(path)
    }, File.expand_path(locale_path)
    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
  end

  def test_english_interface_keys_resolve_without_missing_translations
    I18n.with_locale(:en) do
      EXPECTED_KEYS.each do |key, english|
        full_key = "recording_studio.admin.#{key}"
        translation = I18n.t(full_key, default: nil)

        assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
        assert_equal english, I18n.t(full_key, raise: true)
      end

      assert_equal "1 row", I18n.t("recording_studio.admin.screens.table.row_count", count: 1)
      assert_equal "0 rows", I18n.t("recording_studio.admin.screens.table.row_count", count: 0)
      assert_equal "5 rows", I18n.t("recording_studio.admin.screens.table.row_count", count: 5)
      assert_equal "Actions for admin@example.com",
                   I18n.t("recording_studio.admin.screens.table.actions_for_email", email: "admin@example.com")
      assert_equal "Open API activity",
                   I18n.t("recording_studio.admin.widgets.open", label: "API activity")
    end
  end

  def test_en_yml_nests_keys_under_recording_studio_admin
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("admin")

    assert tree.key?("navigation")
    assert tree.key?("sections")
    assert tree.key?("screens")
    assert tree.key?("widgets")
  end

  def test_gem_does_not_ship_a_legacy_recording_studio_admin_locale_namespace
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")

    refute tree.key?("recording_studio_admin")
  end

  def test_host_override_of_nested_keys_wins
    host_locale = File.join(Dir.tmpdir, "recording_studio_admin_host_override_#{Process.pid}.yml")
    File.write(host_locale, <<~YAML)
      en:
        recording_studio:
          admin:
            sections:
              index:
                title: "Host admin sections"
    YAML
    I18n.load_path << host_locale
    I18n.reload!

    I18n.with_locale(:en) do
      assert_equal "Host admin sections", I18n.t("recording_studio.admin.sections.index.title")
    end
  ensure
    File.delete(host_locale) if host_locale && File.exist?(host_locale)
    I18n.load_path = @original_load_path.dup
    ensure_gem_locale_loaded!
  end

  def test_no_override_keeps_english_defaults
    I18n.with_locale(:en) do
      assert_equal "Admin sections", I18n.t("recording_studio.admin.sections.index.title")
      assert_equal "Go back", I18n.t("recording_studio.admin.navigation.go_back")
      assert_equal "Columns", I18n.t("recording_studio.admin.screens.table.columns")
      assert_equal "Browse the sections available in this admin context",
                   I18n.t("recording_studio.admin.sections.index.subtitle")
    end
  end

  def test_gemspec_does_not_depend_on_internationalization
    gemspec = File.read(File.expand_path("../recording_studio_admin.gemspec", __dir__))

    refute_includes gemspec, "recording_studio_internationalization"
    refute_includes gemspec, "RecordingStudio_Internationalization"
  end

  def test_dummy_gemfile_does_not_depend_on_internationalization
    gemfile = File.read(File.expand_path("dummy/Gemfile", __dir__))

    refute_includes gemfile, "recording_studio_internationalization"
    refute_includes gemfile, "RecordingStudio_Internationalization"
  end

  private

  def ensure_gem_locale_loaded!
    expanded = File.expand_path(@locale_path)
    loaded = I18n.load_path.map { |path| File.expand_path(path) }
    I18n.load_path << @locale_path unless loaded.include?(expanded)
    I18n.reload!
  end

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end
end
