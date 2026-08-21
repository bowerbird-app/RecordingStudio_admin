# frozen_string_literal: true

require "test_helper"

class UpgradeNotesTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_upgrading_doc_covers_the_2_0_floor_and_mixin_migration
    upgrading = File.read(File.join(ROOT, "docs/UPGRADING.md"))
    changelog = File.read(File.join(ROOT, "CHANGELOG.md"))

    assert_includes upgrading, "## Upgrading to 2.0.0"
    assert_includes upgrading, "recording_studio_accessible ~> 0.6"
    assert_includes upgrading, 'tag: "v0.6.1"'
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
  end

  def test_readme_points_hosts_at_upgrade_notes
    readme = File.read(File.join(ROOT, "README.md"))

    assert_includes readme, "## Upgrading"
    assert_includes readme, "docs/UPGRADING.md"
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
