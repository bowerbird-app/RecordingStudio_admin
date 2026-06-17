# frozen_string_literal: true

require "test_helper"
require "fileutils"
require "tmpdir"
require "generators/recording_studio_admin/install/install_generator"

class InstallGeneratorTest < Minitest::Test
  def with_temp_app
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "app/assets/tailwind"))
      yield dir
    end
  end

  def build_generator(destination_root, options = {})
    RecordingStudioAdmin::Generators::InstallGenerator.new([], options, destination_root: destination_root)
  end

  def test_mount_engine_uses_configured_mount_path_and_accessible_engine
    generator = build_generator("/tmp", mount_path: "/backoffice")
    routes = []

    with_singleton_stub(generator, :route, ->(value) { routes << value }) { generator.mount_engine }

    assert_equal [
      'mount RecordingStudioAccessible::Engine, at: "/backoffice/access"',
      'mount RecordingStudioAdmin::Engine, at: "/backoffice"'
    ], routes
  end

  def test_mount_engine_rejects_unsafe_mount_path
    generator = build_generator("/tmp", mount_path: %(/admin"; system("open"); #))

    assert_raises(ArgumentError) { generator.mount_engine }
  end

  def test_copy_initializer_uses_configured_mount_path_and_access_recording_resolver
    with_temp_app do |dir|
      generator = build_generator(dir, mount_path: "/backoffice")

      generator.copy_initializer

      initializer = File.read(File.join(dir, "config/initializers/recording_studio_admin.rb"))
      assert_includes initializer, 'config.default_mount_path = "/backoffice"'
      assert_includes initializer, "config.access_recording_resolver = lambda do |context|"
    end
  end

  def test_add_tailwind_source_injects_engine_and_flatpack_sources
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@import \"tailwindcss\";\n")
      generator = build_generator(dir)

      with_singleton_stub(Rails, :root, Pathname.new(dir)) do
        with_singleton_stub(generator, :say, nil) { generator.add_tailwind_source }
      end

      css = File.read(css_path)
      assert_includes css, "@theme inline"
      assert_includes css, "--color-primary: var(--color-primary);"
      assert_includes css, "recording_studio_admin/app/views/**/*.erb"
      assert_includes css, "flat_pack/app/components/**/*.{rb,erb}"
    end
  end

  def test_install_guide_mentions_admin_root_and_registration
    install_guide = File.read(File.expand_path("../lib/generators/recording_studio_admin/install/INSTALL.md", __dir__))

    assert_includes install_guide, "recording_studio_admin:admin_root"
    assert_includes install_guide, "Register class-based sections and screens"
    assert_includes install_guide, "authentication_method"
    assert_includes install_guide, "access_recording_resolver"
    assert_includes install_guide, "RecordingStudioAccessible.authorized?"
  end
end
