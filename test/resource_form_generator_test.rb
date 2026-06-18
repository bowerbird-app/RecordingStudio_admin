# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_admin/resource_form/resource_form_generator"

class ResourceFormGeneratorTest < Minitest::Test
  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(dir)
      yield dir
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioAdmin::Generators::ResourceFormGenerator.new(["users"], options, destination_root: destination_root)
  end

  def test_generates_host_owned_resource_controller_views_and_resource_definition
    with_temp_app do |dir|
      generator = build_generator(
        dir,
        model: "User",
        section: "users",
        fields: %w[email:string role:select active:boolean]
      )

      generator.validate_options
      generator.copy_resource_definition
      generator.copy_controller
      generator.copy_views

      resource = File.read(File.join(dir, "app/admin/users/users/resource.rb"))
      controller = File.read(File.join(dir, "app/controllers/admin/users_controller.rb"))
      show_view = File.read(File.join(dir, "app/views/admin/users/show.html.erb"))
      edit_view = File.read(File.join(dir, "app/views/admin/users/edit.html.erb"))

      assert_includes resource, "class UsersResource < RecordingStudioAdmin::Resource"
      assert_includes resource, 'key "users"'
      assert_includes resource, 'section "users"'
      assert_includes resource, "required_role: :admin"
      assert_includes resource, "context.controller.main_app.admin_user_path(record)"
      assert_includes resource, "context.controller.main_app.edit_admin_user_path(record)"

      assert_includes controller, "class Admin::UsersController < BaseController"
      assert_includes controller, "before_action :authorize_users_admin_action!"
      assert_includes controller, 'resource_action = action_name == "update" ? :edit : action_name'
      assert_includes controller, "RecordingStudioAdmin.authorize_resource!("
      assert_includes controller, 'key: "users"'
      assert_includes controller, 'audit_action: action_name'
      assert_includes controller, 'perform_recording_studio_admin_action!("users", :edit, @user, audit_action: :update)'
      assert_includes controller, "head :forbidden"
      assert_includes controller, "params.require(:user).permit(:email, :role, :active)"
      assert_includes controller, 'redirect_to recording_studio_admin_context.admin_screen_path("users")'

      assert_includes show_view, "recording_studio_admin/shared/page_shell"
      assert_includes show_view, "FlatPack::PageTitle::Component"
      assert_includes show_view, "FlatPack::Table::Component"
      assert_includes show_view, "preserve_anchor_url(@edit_user_action.url)"

      assert_includes edit_view, "FlatPack::EmailInput::Component"
      assert_includes edit_view, "FlatPack::Select::Component"
      assert_includes edit_view, "FlatPack::Checkbox::Component"
      assert_includes edit_view, "FlatPack::Button::Component.new(text: \"Save\""
    end
  end

  def test_add_route_keeps_mutations_in_host_app_namespace
    generator = build_generator("/tmp", model: "User", section: "users", fields: %w[email:string])
    routes = []

    with_singleton_stub(generator, :route, ->(value) { routes << value }) { generator.add_route }

    assert_equal ["namespace :admin do\n    resources :users, only: %i[show edit update]\n  end"], routes
  end

  def test_validates_required_options_and_unsafe_names
    assert_raises(ArgumentError) do
      build_generator("/tmp", section: "users", fields: %w[email:string]).validate_options
    end

    assert_raises(ArgumentError) do
      build_generator("/tmp", model: "User", section: "users").validate_options
    end

    assert_raises(ArgumentError) do
      build_generator("/tmp", model: "User", section: "../../users", fields: %w[email:string]).validate_options
    end
  end
end