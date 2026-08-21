# frozen_string_literal: true

require_relative "lib/recording_studio_admin/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_admin"
  spec.version     = RecordingStudioAdmin::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudioAdmin"
  spec.summary     = "RecordingStudioAdmin screens and admin scaffolding for Recording Studio"
  spec.description = "A Rails engine for code-defined Recording Studio admin and reporting screens " \
                     "rendered with FlatPack."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "flat_pack", "~> 0.1.129"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio_accessible", "~> 0.6"
end
