# frozen_string_literal: true

require "test_helper"

class UpgradeNotesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_upgrading_doc_covers_the_2_1_0_i18n_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))

    assert_includes upgrading, "## Upgrading to 2.1.0"
    assert_includes upgrading, "recording_studio.admin"
    assert_includes upgrading, "config/locales/en.yml"
    assert_includes upgrading, "no prior top-level `recording_studio_admin.*` locale namespace"
    assert_includes upgrading, "No public constants, methods, or helpers"

    assert_includes changelog, "## 2.1.0"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-210"
    assert_includes changelog, "recording_studio.admin"

    assert_includes readme, "### Interface text"
    assert_includes readme, "recording_studio.admin"
  end

  def test_upgrading_doc_covers_the_2_2_0_i18n_wave_2_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))

    assert_includes upgrading, "## Upgrading to 2.2.0"
    assert_includes upgrading, "search_groups"
    assert_includes upgrading, "date_presets"
    assert_includes upgrading, "QUICK_PRESET_LABELS"
    assert_includes upgrading, "default:"

    assert_includes changelog, "## 2.2.0"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-220"
    assert_includes changelog, "search group headings"
    assert_includes changelog, "date-preset"

    assert_includes readme, "date-preset labels"
    assert_includes readme, "QUICK_PRESET_LABELS"
  end

  def test_upgrading_doc_covers_the_2_7_0_layout_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    gemspec = File.read(File.join(ROOT, "recording_studio_admin.gemspec"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))

    assert_includes version, 'VERSION = "2.7.1"'
    assert_includes gemspec, 'recording_studio", ">= 6.1.0"'
    assert_includes gemspec, 'view_component", ">= 4.14", "< 5"'
    assert_includes gemfile, 'tag: "v6.1.0"'
    assert_includes gemfile, 'tag: "v0.21.0"'
    assert_includes gemfile, 'tag: "v0.12.0"'

    assert_includes upgrading, "## Upgrading to 2.7.0"
    assert_includes upgrading, "config.layout"
    assert_includes upgrading, "flat_pack_page_nav"
    assert_includes upgrading, "register_page_nav"
    assert_includes upgrading, "recording_studio_layout"

    assert_includes changelog, "## 2.7.0"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-270"
    assert_includes changelog, "engine_layout"

    assert_includes upgrading, "engine_layout"
  end

  def test_upgrading_doc_covers_the_2_7_1_compact_widget_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))

    assert_includes version, 'VERSION = "2.7.1"'
    assert_includes upgrading, "## Upgrading to 2.7.1"
    assert_includes upgrading, "min-h-28"
    assert_includes upgrading, "plotOptions.radialBar.dataLabels.value.show"
    assert_includes changelog, "## 2.7.1"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-271"
    assert_includes readme, "2.7.1"
    assert_includes readme, "docs/UPGRADING.md#upgrading-to-271"
  end

  def test_upgrading_doc_covers_the_2_6_2_dev_dummy_pins
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))
    dummy_gemfile = File.read(File.join(ROOT, "test/dummy/Gemfile"))

    assert_includes version, 'VERSION = "2.7.1"'
    assert_includes gemfile, 'RecordingStudio_logs", tag: "v0.7.0"'
    assert_includes gemfile, 'RecordingStudio_metrics", tag: "v0.6.1"'
    assert_includes dummy_gemfile, 'RecordingStudio_logs", tag: "v0.7.0"'
    assert_includes dummy_gemfile, 'RecordingStudio_metrics", tag: "v0.6.1"'

    assert_includes upgrading, "## Upgrading to 2.6.2"
    assert_includes upgrading, "v0.7.0"
    assert_includes upgrading, "v0.6.1"
    assert_includes upgrading, "No runtime code change"

    assert_includes changelog, "## 2.6.2"
    assert_includes changelog, "v0.7.0"
    assert_includes changelog, "v0.6.1"
    assert_includes changelog, "No runtime code change"
  end

  def test_upgrading_doc_covers_the_2_6_1_logs_ceiling
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))

    assert_includes upgrading, "## Upgrading to 2.6.1"
    assert_includes upgrading, ">= 0.4.1, < 1.0"
    assert_includes upgrading, "CI tested with 0.5.0"
    assert_includes upgrading, "No code change"

    assert_includes changelog, "## 2.6.1"
    assert_includes changelog, ">= 0.4.1, < 1.0"
    assert_includes changelog, "CI tested with 0.5.0"
    assert_includes changelog, "No code change"
  end

  def test_upgrading_doc_covers_the_2_6_0_logs_adoption
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    gemspec = File.read(File.join(ROOT, "recording_studio_admin.gemspec"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))
    dummy_gemfile = File.read(File.join(ROOT, "test/dummy/Gemfile"))
    registration = File.read(File.join(ROOT, "lib/recording_studio_admin/logs_registration.rb"))

    assert_includes version, 'VERSION = "2.7.1"'
    assert_includes gemspec, '"recording_studio_logs", ">= 0.4.1", "< 1.0"'
    assert_includes gemfile, 'tag: "v0.7.0"'
    assert_includes dummy_gemfile, 'RecordingStudio_logs", tag: "v0.7.0"'
    assert_includes registration, "partition_interval: nil"
    assert_includes registration, "retention: resolved_retention"
    assert_includes registration, "root_column: :root_recording_id"
    refute_includes registration, "RecordingStudioLogs.aggregate("
    refute_includes registration, "admin/audit_counts"
    refute_includes registration, "actor_type:"
    refute_includes registration, "ip_address:"
    refute_includes registration, "user_agent:"
    refute_includes registration, "request_id:"
    refute_includes registration, "error_class:"
    refute_includes registration, "error_message:"

    assert_includes upgrading, "## Upgrading to 2.6.0"
    assert_includes upgrading, "recording_studio_admin:logs"
    assert_includes upgrading, ":indefinite"
    assert_includes upgrading, "admin_audit_logs"
    assert_includes upgrading, "Cleanup waiting"
    refute_includes upgrading, "logs_summaries_enabled"
    refute_includes upgrading, "admin_audit_day_summaries"

    assert_includes changelog, "## 2.6.0"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-260"
    assert_includes changelog, "recording_studio_logs"
    assert_includes changelog, "No summary or aggregate tables"
    refute_includes changelog, "logs_summaries_enabled"

    assert_includes readme, "2.6.0"
    assert_includes readme, "There is no summary table"
    refute_includes readme, "logs_summaries_enabled"
    refute_includes readme, "admin/audit_counts"
  end

  def test_upgrading_doc_covers_the_2_5_1_admin_activity_logs_layout
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    screen = File.read(File.join(ROOT, "lib/recording_studio_admin/admin_activity_logs_screen.rb"))
    section = File.read(File.join(ROOT, "lib/recording_studio_admin/admin_activity_logs_section.rb"))

    assert_includes version, 'VERSION = "2.7.1"'
    refute_includes screen, 'widget "widgets.admin_activity_logs.activity_overview"'
    assert_includes screen, "filter_presentation :modal, inline_count: 2"
    assert_includes section, 'widget "widgets.admin_activity_logs.activity_overview"'
    assert_includes section, "style: :secondary"

    assert_includes upgrading, "## Upgrading to 2.5.1"
    assert_includes upgrading, "Admin activity overview"
    assert_includes upgrading, "inline_count: 2"
    assert_includes upgrading, "section, not the screen"

    assert_includes changelog, "## 2.5.1"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-251"
    assert_includes changelog, "inline"

    assert_includes readme, "2.5.1"
    assert_includes readme, "Admin activity overview"
  end

  def test_upgrading_doc_covers_the_2_5_0_date_series_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    support = File.read(File.join(ROOT, "lib/recording_studio_admin/admin_activity_logs_support.rb"))

    assert_includes version, 'VERSION = "2.7.1"'
    assert_includes support, "def date_series(relation, field: :created_at, bucket: :day)"
    assert_includes support, "MAX_DATE_SERIES_BUCKETS = 1_000"

    assert_includes upgrading, "## Upgrading to 2.5.0"
    assert_includes upgrading, "date_series"
    assert_includes upgrading, "empty buckets"
    assert_includes upgrading, "1_000"

    assert_includes changelog, "## 2.5.0"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-250"
    assert_includes changelog, "date_series"
    assert_includes changelog, "0"

    assert_includes readme, "2.5.0"
    assert_includes readme, "date_series"
  end

  def test_upgrading_doc_covers_the_2_4_0_flatpack_card_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    gemspec = File.read(File.join(ROOT, "recording_studio_admin.gemspec"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))
    dummy_gemfile = File.read(File.join(ROOT, "test/dummy/Gemfile"))
    views = Dir[File.join(ROOT, "app/views/**/*.erb")].map { |path| File.read(path) }.join

    assert_includes version, 'VERSION = "2.7.1"'
    assert_includes gemspec, 'flat_pack", ">= 0.1.315"'
    assert_includes gemfile, 'ref: "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"'
    assert_includes dummy_gemfile, 'ref: "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"'
    refute_includes views, "style: :outlined"

    assert_includes upgrading, "## Upgrading to 2.4.0"
    assert_includes upgrading, "border: :strong"
    assert_includes upgrading, 'tag: "v0.1.254"'
    assert_includes upgrading, ":brand_subtle"

    assert_includes changelog, "## 2.4.0"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-240"
    assert_includes changelog, "v0.1.254"
    assert_includes changelog, "border: :strong"

    assert_includes readme, "2.4.0"
    assert_includes readme, "v0.1.254"
    assert_includes readme, "border: :strong"
    assert_includes readme, "FlatPack `~> 0.1.254`"
    assert_includes readme, "overrides must move to `border: :strong`"
  end

  def test_upgrading_doc_covers_the_2_3_0_trashable_api_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    gemspec = File.read(File.join(ROOT, "recording_studio_admin.gemspec"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))
    resolver = File.read(File.join(ROOT, "lib/recording_studio_admin/section_recording_resolver.rb"))

    assert_includes version, 'VERSION = "2.7.1"'
    assert_includes gemspec, 'recording_studio_trashable", "~> 0.10"'
    assert_includes gemfile, 'tag: "v0.12.0"'
    assert_includes gemfile, "require: false"
    assert_includes gemfile, "recording_studio_trashable"
    assert_includes resolver, "recording_studio_trashable_kept_sql"
    assert_includes resolver, "kept_sql_available?"
    refute_includes resolver, "recording_studio_trashable_active.find_by"

    assert_includes upgrading, "## Upgrading to 2.3.0"
    assert_includes upgrading, "recording_studio_trashable_kept_sql"
    assert_includes upgrading, 'tag: "v0.10.0"'
    assert_includes upgrading, "require: false"
    assert_includes upgrading, "query-only"
    assert_includes upgrading, "same"
    assert_includes upgrading, "`unscoped` base matches main"
    assert_includes upgrading, "recording_studio_metrics"
    assert_includes upgrading, 'tag: "v0.2.0"'

    assert_includes changelog, "## 2.3.0"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-230"
    assert_includes changelog, "recording_studio_trashable"
    assert_includes changelog, "~> 0.10"
    assert_includes changelog, "recording_studio_trashable/query"

    assert_includes readme, "2.3.0"
    assert_includes readme, "recording_studio_trashable_kept_sql"
    refute_includes readme, "recording_studio_trashable_active.find_by(recordable: admin_root)"

    assert_includes resolver, "unscoped.find_by(find_attrs.merge(trashed_at: nil))"
    assert_includes resolver, "kept_recordings"
    engine = File.read(File.join(ROOT, "lib/recording_studio_admin/engine.rb"))
    assert_includes engine, 'require "recording_studio_trashable/query"'
  end

  def test_upgrading_doc_covers_the_2_0_floor_and_mixin_migration
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))

    assert_includes upgrading, "## Upgrading to 2.0.0"
    assert_includes upgrading, "recording_studio_accessible ~> 0.6"
    assert_includes upgrading, 'tag: "v4.7.0"'
    assert_includes upgrading, 'tag: "v0.18.0"'
    assert_includes upgrading, "RecordingStudio.enable_capability(:accessible, on: self)"
    assert_includes upgrading, "bootstrap_owner_access!"
    assert_includes upgrading, "Keep **AdminRoot owned**"
    assert_includes upgrading, "recording_studio_billing"
    assert_includes upgrading, "recording_studio_webhooks"
    assert_includes upgrading, "Phase 6"
    assert_includes upgrading, "`AllowsAccessibleChildren` and `recording_studio_accessible_children` are gone"

    assert_includes changelog, "### Upgrade Notes"
    assert_includes changelog, "docs/UPGRADING.md"
    assert_includes changelog, "Webhooks tracks this repo untagged"
    assert_includes changelog, "Accessible `0.8`–`0.11` migrations"
  end

  def test_readme_points_hosts_at_upgrade_notes
    readme = File.read(File.join(ROOT, "README.md"))

    assert_includes readme, "## Upgrading"
    assert_includes readme, "docs/UPGRADING.md"
    assert_includes readme, "RecordingStudio `v6.1.0`"
    assert_includes readme, "Accessible `v0.21.0`"
    assert_includes readme, "bootstrap_owner_access!"
  end

  def test_docs_cover_cloud_agent_boot_and_the_2_0_2_rebuild
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))

    assert_includes upgrading, "## Upgrading to 2.0.2"
    assert_includes upgrading, "Rebuild the Cloud Agent environment with Draft off"
    assert_includes upgrading, "cursor-skills.md"

    assert_includes changelog, "## 2.0.2"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-202"
    assert_includes changelog, "Draft off"

    assert_includes readme, "## Cloud Agent boot"
    assert_includes readme, "docs/cursor-skills.md"
  end

  def test_docs_cover_frame_endpoints_and_the_2_0_1_page_load_redirect
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))

    assert_includes upgrading, "## Upgrading to 2.0.1"
    assert_includes upgrading, "Sec-Fetch-Dest: document"
    assert_includes upgrading, "### Verify the upgrade"

    assert_includes changelog, "## 2.0.1"
    assert_includes changelog, "docs/UPGRADING.md#upgrading-to-201"

    assert_includes readme, "### Frame endpoints"
    assert_includes readme, "/admin/screens/:key/table_count"
    assert_includes readme, "`Sec-Fetch-Dest: document`"
  end
end
