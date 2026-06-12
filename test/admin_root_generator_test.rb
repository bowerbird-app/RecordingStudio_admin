# frozen_string_literal: true

require "test_helper"

class AdminRootGeneratorTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GENERATOR_TEMPLATE_ROOT = "lib/generators/recording_studio_admin/admin_root/templates"

  def test_generated_admin_base_controller_pattern
    template = File.read(generator_template_path("app/controllers/admin/base_controller.rb"))

    assert_includes template, "class Admin::BaseController < ApplicationController"
    assert_includes template, 'layout "admin"'
    assert_includes template, "before_action :authenticate_admin_user!"
    assert_includes template, "before_action :authorize_admin_user!"
    assert_includes template, "head :unauthorized"
    assert_includes template, "head :forbidden"
  end

  def test_generated_admin_root_includes_accessible_children
    template = File.read(generator_template_path("app/models/admin_root.rb"))

    assert_includes template, "include RecordingStudioAccessible::AllowsAccessibleChildren"
    assert_includes template, "recording_studio_accessible_children :access"
  end

  def test_admin_root_route_does_not_conflict_with_default_engine_mount
    source = File.read(File.join(ROOT, "lib/generators/recording_studio_admin/admin_root/admin_root_generator.rb"))

    assert_includes source, 'get "root", to: "root#show"'
    refute_includes source, 'root "root#show"'
  end

  def test_admin_root_view_links_to_configured_engine_mount_path
    template = File.read(generator_template_path("app/views/admin/root/show.html.erb"))

    assert_includes template, "RecordingStudioAdmin.configuration.default_mount_path"
  end

  private

  def generator_template_path(path)
    File.join(ROOT, GENERATOR_TEMPLATE_ROOT, path)
  end
end
