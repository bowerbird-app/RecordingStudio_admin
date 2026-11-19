# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_admin.gemspec
gemspec

gem "flat_pack", "~> 0.2", github: "bowerbird-app/flatpack", tag: "v0.2.0"
gem "recording_studio", "~> 7.8", github: "bowerbird-app/RecordingStudio", tag: "v7.8.0"
gem "recording_studio_accessible", "~> 0.58", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.58.0"
gem "recording_studio_logs", "~> 0.9", github: "bowerbird-app/RecordingStudio_logs", tag: "v0.9.0"
# Trashable's gemspec still lists metrics; pin the git source for Bundler resolution.
gem "recording_studio_metrics", "~> 0.10", github: "bowerbird-app/RecordingStudio_metrics", tag: "v0.10.0",
                                           require: false
gem "recording_studio_trashable", "~> 1.3", github: "bowerbird-app/RecordingStudio_trashable", tag: "v1.3.0",
                                            require: false
gem "view_component", "~> 4.20"

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
