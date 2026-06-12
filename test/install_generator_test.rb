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
    generator = build_generator("/tmp", mount_path: "/admin")
    routes = []

    generator.stub(:route, ->(value) { routes << value }) { generator.mount_engine }

    assert_includes routes, 'mount RecordingStudioAdmin::Engine, at: "/admin"'
    assert_includes routes, 'mount RecordingStudioAccessible::Engine, at: "/admin/access"'
  end

  def test_add_tailwind_source_injects_engine_and_flatpack_sources
    with_temp_app do |dir|
      css_path = File.join(dir, "app/assets/tailwind/application.css")
      File.write(css_path, "@import \"tailwindcss\";\n")
      generator = build_generator(dir)

      Rails.stub(:root, Pathname.new(dir)) do
        generator.stub(:say, nil) { generator.add_tailwind_source }
      end

      css = File.read(css_path)
      assert_includes css, "recording_studio_admin/app/views/**/*.erb"
      assert_includes css, "flat_pack/app/components/**/*.{rb,erb}"
    end
  end

  def test_install_guide_mentions_admin_root_and_registration
    install_guide = File.read(File.expand_path("../lib/generators/recording_studio_admin/install/INSTALL.md", __dir__))

    assert_includes install_guide, "recording_studio_admin:admin_root"
    assert_includes install_guide, "Register class-based sections and screens"
  end
end
