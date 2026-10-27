# frozen_string_literal: true

source "https://rubygems.org"

require_relative "test/support/widen_recording_studio_requirement"

# Specify your gem's dependencies in recording_studio_admin.gemspec
gemspec

# Private RecordingStudio ecosystem dependencies used by the engine during development/test.
gem "flat_pack", github: "bowerbird-app/flatpack", ref: "1fcbafe94f8eb118f0a22182f63f5110fcc97a56"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.1.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.21.0"
gem "recording_studio_logs", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.7.0"
# Trashable's gemspec still lists metrics; pin the git source for Bundler resolution.
# Admin loads query-only helpers and does not boot Trashable's engine/metrics.
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.6.1",
                                require: false
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable", tag: "v0.12.0",
                                  require: false
gem "view_component", "4.19.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest-mock"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
