# frozen_string_literal: true

require "test_helper"

class AdminRootGeneratorTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_generated_admin_base_controller_pattern
    template = File.read(File.join(ROOT, "lib/generators/recording_studio_admin/admin_root/templates/app/controllers/admin/base_controller.rb"))

    assert_includes template, "class Admin::BaseController < ApplicationController"
    assert_includes template, 'layout "admin"'
  end

  def test_generated_admin_root_includes_accessible_children
    template = File.read(File.join(ROOT, "lib/generators/recording_studio_admin/admin_root/templates/app/models/admin_root.rb"))

    assert_includes template, "include RecordingStudioAccessible::AllowsAccessibleChildren"
    assert_includes template, "recording_studio_accessible_children :access"
  end
end
