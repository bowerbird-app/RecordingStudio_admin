# frozen_string_literal: true

require "simplecov"

root = File.expand_path("..", __dir__)
resultset = File.join(root, "coverage/.resultset.json")
abort "No coverage resultset at #{resultset}. Run the gem and dummy suites first." unless File.file?(resultset)

SimpleCov.collate([resultset]) do
  enable_coverage :branch
  root root
  coverage_dir File.join(root, "coverage")
  skip "/test/"
  skip "/config/"
  skip "/db/"
  minimum_coverage line: 94
end
