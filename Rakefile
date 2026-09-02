# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

DUMMY_TEST_FILES = [
  File.expand_path("test/controllers/docs_controller_test.rb", __dir__),
  File.expand_path("test/recording_studio_v3_test.rb", __dir__)
].freeze
DUMMY_GEMFILE = File.expand_path("test/dummy/Gemfile", __dir__)
DUMMY_APP_ROOT = File.expand_path("test/dummy", __dir__)
DUMMY_APP_TEST_FILES = %w[
  test/cursor_boot_files_test.rb
  test/integration/admin_layout_width_consistency_test.rb
  test/integration/admin_resource_crud_test.rb
  test/integration/admin_section_rendering_test.rb
  test/integration/dummy_access_enforcement_test.rb
  test/integration/recording_studio_v3_template_test.rb
  test/integration/root_switch_dropdown_test.rb
  test/integration/stats_root_test.rb
].freeze
TEST_ROOT = File.expand_path("test", __dir__)
TEST_DATABASE_NAME = "recording_studio_admin_test"
ROOT_TEST_EXCLUSIONS = %w[
  test/controllers/docs_controller_test.rb
  test/dummy/**/*_test.rb
  test/recording_studio_v3_test.rb
  test/rename_verification_test.rb
].freeze
DUMMY_BUNDLE_CLEARED_ENV = {
  "BUNDLE_APP_CONFIG" => nil,
  "BUNDLE_BIN_PATH" => nil,
  "BUNDLE_GEMFILE" => DUMMY_GEMFILE,
  "BUNDLE_LOCKFILE" => nil,
  "BUNDLER_SETUP" => nil,
  "BUNDLER_VERSION" => nil,
  "RUBYLIB" => nil,
  "RUBYOPT" => nil
}.freeze

def run_command!(env, *command)
  return if Bundler.with_unbundled_env { system(env, *command) }

  raise "Command failed (#{Process.last_status.exitstatus}): #{command.join(' ')}"
end

def bundle_satisfied?(env)
  Bundler.with_unbundled_env { system(env, "bundle", "check", out: File::NULL, err: File::NULL) }
end

def dummy_bundle_env
  dummy_bundle_base_env.merge(DUMMY_BUNDLE_CLEARED_ENV)
end

def dummy_bundle_base_env
  env = dummy_bundle_process_env.merge(dummy_database_env)
  bundle_path = ENV.fetch("BUNDLE_PATH", nil)

  env["BUNDLE_PATH"] = bundle_path if bundle_path.to_s != ""
  env.compact
end

def dummy_bundle_process_env
  {
    "BUNDLE_GEMFILE" => DUMMY_GEMFILE,
    "DISABLE_SIMPLECOV" => "true",
    "DATABASE_URL" => ENV.fetch("DATABASE_URL", nil)
  }
end

def dummy_database_env
  {
    "RAILS_ENV" => ENV.fetch("RAILS_ENV", "test"),
    "DB_HOST" => ENV.fetch("DB_HOST", "localhost"),
    "DB_PORT" => ENV.fetch("DB_PORT", "5432"),
    "DB_USER" => ENV.fetch("DB_USER", "postgres"),
    "DB_PASSWORD" => ENV.fetch("DB_PASSWORD", "postgres"),
    "DB_NAME" => dummy_test_database_name,
    "DB_NAME_TEST" => dummy_test_database_name
  }
end

def dummy_test_database_name
  ENV.fetch("DB_NAME_TEST", TEST_DATABASE_NAME)
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"].exclude(*ROOT_TEST_EXCLUSIONS)
  t.verbose = false
end

namespace :test do
  desc "Run rename verification tests to validate gem naming consistency"
  task :rename_verification do
    ruby "test/rename_verification_test.rb", verbose: true
  end

  desc "Run rename verification tests in verbose mode"
  task :rename_verification_verbose do
    ruby "test/rename_verification_test.rb", "--verbose", verbose: true
  end

  desc "Run dummy app integration tests under the dummy app bundle"
  task :dummy do
    Dir.chdir(DUMMY_APP_ROOT) do
      env = dummy_bundle_env

      run_command!(env, "bundle", "install") unless bundle_satisfied?(env)
      run_command!(env, "bundle", "exec", "bin/rails", "db:test:prepare")
      DUMMY_APP_TEST_FILES.each do |test_file|
        run_command!(env, "bundle", "exec", "bin/rails", "test", test_file)
      end
      DUMMY_TEST_FILES.each do |test_file|
        run_command!(env, "bundle", "exec", "ruby", "-I#{TEST_ROOT}", test_file)
      end
    end
  end

  desc "Run gem and dummy app tests"
  task all: %i[test dummy]
end

namespace :app do
  desc "Run all tests for the gem"
  task test: "test:all"
end

task default: :test
