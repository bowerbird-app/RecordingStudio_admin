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
    expected_helper_method =
      "helper_method :recording_studio_admin_context, :recording_studio_admin_access_recording, " \
      ":page_nav_anchor_url,"
    assert_includes template, expected_helper_method
    assert_includes template, ":preserve_anchor_url"
    assert_includes template, "RecordingStudioAdmin::Authorization.authorize!("
    assert_includes template, "recording_studio_admin_context,"
    assert_includes template, "recording: recording_studio_admin_access_recording"
    assert_includes template, "RecordingStudioAdmin::Context.new"
    assert_includes template, "def recording_studio_admin_access_recording"
    assert_includes template, "AdminRoot.find_or_create_by!(name: \"Admin\")"
    assert_includes template, "RecordingStudio.root_recording_for(admin_root)"
    assert_includes template, "def page_nav_anchor_url"
    assert_includes template, "RecordingStudioAdmin::UrlSafety.safe_href(params[:anchor_url], allow_external: true)"
    assert_includes template, "def preserve_anchor_url(url)"
    assert_includes template, "reverse_merge(\"anchor_url\" => anchor_url)"
    assert_includes template, "head :unauthorized"
    assert_includes template, "head :forbidden"
  end

  def test_generated_admin_root_includes_accessible_children
    template = File.read(generator_template_path("app/models/admin_root.rb"))
    admin_audit_log_template = File.read(generator_template_path("app/models/admin_audit_log.rb"))
    audit_migration_template = File.read(generator_template_path("db/migrate/create_admin_audit_logs.rb"))
    generator_source = File.read(File.join(ROOT, "lib/generators/recording_studio_admin/admin_root/admin_root_generator.rb"))

    assert_includes template, "include RecordingStudioAccessible::AllowsAccessibleChildren"
    assert_includes template, "include RecordingStudioAdmin::AllowsAdminSections"
    assert_includes template, "recording_studio_accessible_children :access"
    assert_includes template, "recording_studio_admin_sections do"
    assert_includes template, "section :root"
    assert_includes template, "section :admin_activity_logs"
    assert_includes admin_audit_log_template, "class AdminAuditLog < ApplicationRecord"
    assert_includes admin_audit_log_template, "def self.record_admin_action!(event)"
    assert_includes audit_migration_template, "create_table :admin_audit_logs"
    refute_includes generator_source, 'template "app/admin/admin_activity_logs/admin_activity_logs/screen.rb"'
    refute_includes generator_source, 'template "app/admin/admin_activity_logs/section.rb"'
  end

  def test_admin_root_route_does_not_conflict_with_default_engine_mount
    source = File.read(File.join(ROOT, "lib/generators/recording_studio_admin/admin_root/admin_root_generator.rb"))

    assert_includes source, 'get "root", to: "root#show"'
    refute_includes source, 'root "root#show"'
  end

  def test_admin_root_view_lists_available_admin_sections
    template = File.read(generator_template_path("app/views/admin/root/show.html.erb"))

    expected_available_sections =
      "recording_studio_admin_context.available_admin_sections(recording: " \
      "recording_studio_admin_access_recording)"
    assert_includes template, expected_available_sections
    assert_includes template, "recording_studio_admin_context.available_admin_items("
    assert_includes template, "include: %i[sections screens]"
    refute_includes template, "parent: :root"
    assert_includes template, "FlatPack::SearchInput::Component"
    assert_includes template, "FlatPack::Badge::Component"
    assert_includes template, "placeholder: \"Search\""
    assert_includes template, 'data-controller="admin--root-search"'
    assert_includes template, 'data-action="input->admin--root-search#filter search->admin--root-search#filter"'
    assert_includes template, 'data-admin--root-search-target="results"'
    assert_includes template, 'admin__root_search_target: "item"'
    assert_includes template, "hidden: !item_matches_search"
    assert_includes template, "No admin screens or sections match that search."
    assert_includes template, "FlatPack::PageNav::Component.new(anchor_url: page_nav_anchor_url"
    assert_includes template, "href: preserve_anchor_url(section.url)"
    assert_includes template, "FlatPack::List::Component"
    assert_includes template, "FlatPack::List::Item"
    assert_includes template, "FlatPack::Shared::IconComponent"
    assert_includes template, "section.title"
    assert_includes template, "section.subtitle"
    assert_includes template, "section.url"
    assert_includes template, "No admin sections are available."
    refute_includes template, "Open admin screens"
  end

  def test_admin_root_generator_includes_live_search_controller_template
    template = File.read(generator_template_path("app/javascript/controllers/admin/root_search_controller.js"))

    assert_includes template, 'static targets = ["input", "results", "emptyState", "item"]'
    assert_includes template, "this.filter()"
    assert_includes template, "item.hidden = !matches"
    assert_includes template, "this.resultsTarget.hidden = query.length === 0 || visibleCount === 0"
  end

  private

  def generator_template_path(path)
    File.join(ROOT, GENERATOR_TEMPLATE_ROOT, path)
  end
end
