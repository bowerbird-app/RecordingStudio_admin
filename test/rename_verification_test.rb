# frozen_string_literal: true

require_relative "simplecov_helper"
require "minitest/autorun"

class RenameVerificationTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_canonical_files_exist
    assert File.exist?(File.join(ROOT, "recording_studio_admin.gemspec"))
    assert File.exist?(File.join(ROOT, "lib/recording_studio_admin.rb"))
    assert File.exist?(File.join(ROOT, "lib/recording_studio_admin/engine.rb"))
    assert Dir.exist?(File.join(ROOT, "app/controllers/recording_studio_admin"))
  end

  def test_no_old_template_public_code_references
    leftovers = searchable_files.select do |path|
      content = File.read(path)
      %w[GemTemplate gem_template Admin2 admin_2].any? { |term| content.include?(term) }
    end

    assert_empty(leftovers.map { |path| path.sub("#{ROOT}/", "") })
  end

  def test_version_file_loads
    $LOAD_PATH.unshift(File.join(ROOT, "lib")) unless $LOAD_PATH.include?(File.join(ROOT, "lib"))
    require "recording_studio_admin/version"

    assert_equal "1.0.1", RecordingStudioAdmin::VERSION
  end

  private

  def searchable_files
    patterns = %w[*.rb *.md *.erb *.rake *.yml *.yaml *.gemspec Gemfile Rakefile]
    patterns.flat_map { |pattern| Dir.glob(File.join(ROOT, "**", pattern)) }.uniq.reject do |path|
      relative = path.sub("#{ROOT}/", "")
      relative.start_with?(".git/", "coverage/", "docs/gem_template/",
                           ".github/agents/") || relative == "test/rename_verification_test.rb"
    end
  end
end
