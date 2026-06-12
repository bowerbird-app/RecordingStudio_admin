# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_admin.gemspec
gemspec

# Private RecordingStudio ecosystem dependencies used by the engine during development/test.
gem "flat_pack", github: "bowerbird-app/flatpack", ref: "43fb089b791faa76fb30557a1a1a682728f9a1e8"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "recording_studio/v3.0.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "0.3.1"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
