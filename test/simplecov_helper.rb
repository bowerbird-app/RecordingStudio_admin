# frozen_string_literal: true

return if ENV["DISABLE_SIMPLECOV"] == "true"

begin
  require "simplecov"
rescue LoadError
  return
end

# Gem and dummy suites are separate processes. Each process stores its slice
# under a stable command name. `rake test:all` clears coverage/, runs both
# suites, then collates the result and enforces the line minimum.
module AdminSuiteCoverage
  ROOT = File.expand_path("..", __dir__)
  LINE_MINIMUM = 94
  MERGE_TIMEOUT = 7_200

  module_function

  def start!
    SimpleCov.start do
      enable_coverage :branch
      root AdminSuiteCoverage::ROOT
      coverage_dir File.join(AdminSuiteCoverage::ROOT, "coverage")
      command_name AdminSuiteCoverage.command_name
      merge_timeout AdminSuiteCoverage::MERGE_TIMEOUT
      skip "/test/"
      skip "/config/"
      skip "/db/"
    end
  end

  def command_name
    explicit = ENV.fetch("SIMPLECOV_COMMAND_NAME", "")
    return explicit unless explicit.empty?

    "gem"
  end
end

AdminSuiteCoverage.start!
