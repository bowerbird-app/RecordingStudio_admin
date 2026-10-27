# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "minitest/autorun"
require_relative "dummy/lib/tailwind_gem_sources"

class DummyTailwindSourceTest < Minitest::Test
  def setup
    @css = File.read(File.expand_path("dummy/app/assets/tailwind/application.css", __dir__))
  end

  def test_dummy_tailwind_scans_linked_gems_and_skips_host_tokens
    assert_includes @css, "./gem_sources/flatpack/app/components"
    assert_includes @css, "./gem_sources/flatpack/app/helpers"
    assert_includes @css, "./gem_sources/recording_studio/app/views"
    assert_includes @css, "./gem_sources/recording_studio/app/helpers"
    assert_includes @css, "./gem_sources/recording_studio_accessible/app/components"
    assert_includes @css, "./gem_sources/recording_studio_root_switchable/app/helpers"
    assert_includes @css, '@source "../../../../../lib";'
    assert_includes @css, '@source "../../../../../app/javascript";'
    refute_includes @css, "@theme inline {"
    refute_includes @css, "@theme {"
    refute_includes @css, "--color-fp-primary:"
    refute_includes @css, "--radius-md:"
  end

  def test_linker_points_gem_sources_at_the_loaded_specs
    directory = Dir.mktmpdir
    gem_root = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(gem_root, "app/helpers"))
    spec = Struct.new(:full_gem_path).new(gem_root)

    TailwindGemSources.link!(directory, specs: { "flat_pack" => spec })

    link = File.join(directory, "flatpack")
    assert File.symlink?(link)
    assert_equal gem_root, File.readlink(link)
  ensure
    FileUtils.rm_rf(directory) if directory
    FileUtils.rm_rf(gem_root) if gem_root
  end
end
