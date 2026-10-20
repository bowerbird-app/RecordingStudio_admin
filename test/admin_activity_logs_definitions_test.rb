# frozen_string_literal: true

require "test_helper"

class AdminActivityLogsDefinitionsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_overview_widget_is_declared_on_the_section_not_the_screen
    screen = File.read(File.join(ROOT, "lib/recording_studio_admin/admin_activity_logs_screen.rb"))
    section = File.read(File.join(ROOT, "lib/recording_studio_admin/admin_activity_logs_section.rb"))
    template = File.read(
      File.join(ROOT, "lib/generators/recording_studio_admin/admin_root/templates/app/models/admin_root.rb")
    )

    refute_includes screen, 'widget "widgets.admin_activity_logs.activity_overview"'
    assert_includes screen, "filter_presentation :modal, inline_count: 2"
    assert_includes section, 'widget "widgets.admin_activity_logs.activity_overview"'
    assert_includes section, "style: :secondary"
    refute_includes section, "style: :primary"
    assert_includes template, "section :admin_activity_logs"
    refute_includes template, "activity_overview"
  end
end
