# frozen_string_literal: true

require "test_helper"

class AdminRootGeneratorTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GENERATOR_TEMPLATE_ROOT = "lib/generators/recording_studio_admin/admin_root/templates"

  def test_generated_admin_base_controller_pattern
    template = File.read(generator_template_path("app/controllers/admin/base_controller.rb"))

    assert_includes template, "class Admin::BaseController < ApplicationController"
    assert_includes template, 'layout "admin"'
  end

  def test_generated_admin_root_includes_accessible_children
    template = File.read(generator_template_path("app/models/admin_root.rb"))

    assert_includes template, "include RecordingStudioAccessible::AllowsAccessibleChildren"
    assert_includes template, "recording_studio_accessible_children :access"
  end

  private

  def generator_template_path(path)
    File.join(ROOT, GENERATOR_TEMPLATE_ROOT, path)
  end
end
