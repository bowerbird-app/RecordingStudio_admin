# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_admin.gemspec
gemspec

# Private RecordingStudio ecosystem dependencies used by the engine during development/test.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.129"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.1.0"
# Accessible 0.6.1 is on main (PR #15 merged) but not tagged yet; pin the merge commit.
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible",
                                   ref: "f1d777f047aca9eefbdedbb8f0a54eea29838384"

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
