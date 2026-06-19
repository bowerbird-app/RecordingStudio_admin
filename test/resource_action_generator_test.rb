# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_admin/resource_form/resource_form_generator"
require "generators/recording_studio_admin/resource_action/resource_action_generator"

class ResourceActionGeneratorTest < Minitest::Test
  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(dir)
      yield dir
    end
  end

  def build_form_generator(destination_root, options = {})
    RecordingStudioAdmin::Generators::ResourceFormGenerator.new(["users"], options, destination_root: destination_root)
  end

  def build_action_generator(destination_root, options = {})
    RecordingStudioAdmin::Generators::ResourceActionGenerator.new(%w[users flag_email], options,
                                                                  destination_root: destination_root)
  end

  def test_generator_appends_custom_member_action_to_existing_resource_and_controller
    with_temp_app do |dir|
      form_generator = build_form_generator(dir, model: "User", section: "users", fields: %w[email:string])
      form_generator.validate_options
      form_generator.copy_resource_definition
      form_generator.copy_controller
      form_generator.copy_views

      action_generator = build_action_generator(
        dir,
        model: "User",
        section: "users",
        confirm: "Flag this email?"
      )

      action_generator.validate_options
      action_generator.update_resource_definition
      action_generator.update_controller
      action_generator.copy_test

      resource = File.read(File.join(dir, "app/admin/users/users/resource.rb"))
      controller = File.read(File.join(dir, "app/controllers/admin/users_controller.rb"))
      action_test = File.read(File.join(dir, "test/controllers/admin/users_flag_email_test.rb"))

      assert_includes resource, "action :flag_email"
      assert_includes resource, 'text: "Flag email"'
      assert_includes resource, 'icon: "flag"'
      assert_includes resource, "method: :post"
      assert_includes resource, 'confirm: "Flag this email?"'
      assert_includes resource, "context.controller.main_app.flag_email_admin_user_path(record) if record"
      assert_includes resource, "required_role: :admin"

      assert_includes controller, "def flag_email"
      assert_includes controller, 'perform_recording_studio_admin_action!("users", :flag_email, @user)'
      assert_includes controller, "perform_users_flag_email!(@user)"
      assert_includes controller, 'redirect_to recording_studio_admin_context.admin_screen_path("users")'
      assert_includes controller, "def perform_users_flag_email!(record)"
      assert_includes controller, "Replace perform_users_flag_email! with the app-specific mutation"

      assert_includes action_test, "class Admin::UsersFlagEmailTest < ActionDispatch::IntegrationTest"
      assert_includes action_test, "users.flag_email authorization"
    end
  end

  def test_add_route_creates_a_focused_member_route_block
    generator = build_action_generator("/tmp", model: "User", section: "users")
    routes = []
    expected_route = [
      "namespace :admin do\n  resources :users, only: [] do\n    post :flag_email, on: :member\n  end\nend"
    ]

    with_singleton_stub(generator, :route, ->(value) { routes << value }) { generator.add_route }

    assert_equal expected_route, routes
  end

  def test_rejects_missing_host_files_and_unsafe_names
    generator = build_action_generator("/tmp", model: "User", section: "users")

    error = assert_raises(ArgumentError) { generator.update_resource_definition }
    assert_match(/Generate the resource form first/, error.message)

    invalid_generator = RecordingStudioAdmin::Generators::ResourceActionGenerator.new(
      ["users", "../../flag_email"],
      { model: "User", section: "users" },
      destination_root: "/tmp"
    )

    assert_raises(ArgumentError) { invalid_generator.validate_options }
  end

  def test_docs_mention_resource_action_generator
    guide = File.read(File.expand_path("../docs/gem_template/ADMIN_SCREENS.md", __dir__))
    install_guide = File.read(File.expand_path("../lib/generators/recording_studio_admin/install/INSTALL.md", __dir__))

    assert_includes guide, "recording_studio_admin:resource_action"
    assert_includes guide, "custom member actions"
    assert_includes install_guide, "recording_studio_admin:resource_action"
  end
end
