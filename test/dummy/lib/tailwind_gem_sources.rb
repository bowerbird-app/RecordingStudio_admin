# frozen_string_literal: true

require "fileutils"

# Links installed gems to stable directories so Tailwind @source can scan them.
# @source does not expand globs, so the link target is the real gem path.
module TailwindGemSources
  GEMS = {
    "flat_pack" => "flatpack",
    "recording_studio" => "recording_studio",
    "recording_studio_accessible" => "recording_studio_accessible",
    "recording_studio_root_switchable" => "recording_studio_root_switchable"
  }.freeze

  def self.link!(directory, specs: Gem.loaded_specs)
    FileUtils.mkdir_p(directory)

    GEMS.each do |gem_name, folder|
      spec = specs[gem_name]
      next unless spec

      destination = File.join(directory, folder)
      FileUtils.rm_rf(destination) if File.symlink?(destination)
      File.symlink(spec.full_gem_path, destination)
    end
  end
end
