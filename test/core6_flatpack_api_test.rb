# frozen_string_literal: true

require "test_helper"

class Core6FlatpackApiTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  GEM_SOURCES = Dir[
    File.join(ROOT, "app/views/**/*.{erb,rb}"),
    File.join(ROOT, "app/helpers/**/*.rb"),
    File.join(ROOT, "lib/generators/**/*.{erb,rb}")
  ]

  def test_engine_views_and_helpers_use_core_6_page_nav
    GEM_SOURCES.each do |path|
      source = File.read(path)

      refute_match(
        /recording_studio_page_nav[^_]/,
        source,
        "#{relative(path)} still calls recording_studio_page_nav"
      )
      refute_match(
        /\bback_icon:/,
        source,
        "#{relative(path)} still passes PageNav back_icon:"
      )
      refute_match(
        /\banchor_label:/,
        source,
        "#{relative(path)} still passes PageNav anchor_label:"
      )
    end
  end

  def test_engine_cards_do_not_pass_removed_style
    GEM_SOURCES.each do |path|
      source = File.read(path)
      source.scan(/FlatPack::Card::Component\.new\((.*?)\)(?:\s+do)?/m) do |match|
        args = match.first
        refute_match(
          /(?<![a-z_])style:/,
          args,
          "#{relative(path)} passes style: to Card"
        )
      end
    end
  end

  def test_engine_controllers_use_recording_studio_layout
    controller = File.read(
      File.join(ROOT, "app/controllers/recording_studio_admin/application_controller.rb")
    )
    generator = File.read(
      File.join(
        ROOT,
        "lib/generators/recording_studio_admin/admin_root/templates/app/controllers/admin/base_controller.rb"
      )
    )

    assert_includes controller, "recording_studio_layout {"
    assert_includes controller, "RecordingStudioAdmin.configuration.layout_for(recording_studio_admin_surface)"
    refute_match(/^\s*layout\s+["']/, controller)
    assert_includes generator, "recording_studio_layout { RecordingStudioAdmin.configuration.layout }"
    refute_includes generator, 'layout "admin"'
  end

  def test_page_nav_helper_uses_flat_pack_and_register
    helper = File.read(File.join(ROOT, "app/helpers/recording_studio_admin/page_nav_helper.rb"))

    assert_includes helper, "flat_pack_page_nav("
    assert_includes helper, "register_page_nav("
    refute_includes helper, "back_icon:"
    refute_includes helper, "anchor_label:"
  end

  private

  def relative(path)
    path.delete_prefix("#{ROOT}/")
  end
end
