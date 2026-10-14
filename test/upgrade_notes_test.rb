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

  def test_upgrading_doc_covers_the_2_3_0_trashable_api_release
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))
    readme = File.read(File.join(ROOT, "README.md"))
    version = File.read(File.join(ROOT, "lib/recording_studio_admin/version.rb"))
    gemspec = File.read(File.join(ROOT, "recording_studio_admin.gemspec"))
    gemfile = File.read(File.join(ROOT, "Gemfile"))
    resolver = File.read(File.join(ROOT, "lib/recording_studio_admin/section_recording_resolver.rb"))

    assert_includes version, 'VERSION = "2.3.0"'
    assert_includes gemspec, 'recording_studio_trashable", "~> 0.10"'
    assert_includes gemfile, 'tag: "v0.10.0"'
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
    assert_includes upgrading, 'tag: "v4.6.0"'
    assert_includes upgrading, 'tag: "v0.17.0"'
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
    assert_includes readme, "RecordingStudio `v4.6.0`"
    assert_includes readme, "Accessible `v0.17.0`"
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
