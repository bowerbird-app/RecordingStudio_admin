# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require_relative "simplecov_helper"
require "minitest/autorun"
require "rails"
require "recording_studio_admin"
require_relative "support/dummy_access_test_helpers"

module TestStubHelper
  def with_singleton_stub(target, method_name, replacement = nil)
    eigenclass = target.singleton_class
    had_method = target.respond_to?(method_name, true)
    original_method = target.method(method_name) if had_method
    original_visibility = method_visibility(eigenclass, method_name) if had_method
    stub_impl = replacement.respond_to?(:call) ? replacement : ->(*, **) { replacement }

    with_warnings_silenced do
      eigenclass.__send__(:define_method, method_name) do |*args, **kwargs, &block|
        if kwargs.empty?
          stub_impl.call(*args, &block)
        else
          stub_impl.call(*args, **kwargs, &block)
        end
      end
      eigenclass.__send__(original_visibility, method_name) if had_method && original_visibility != :public
    end

    yield
  ensure
    with_warnings_silenced do
      if had_method
        eigenclass.__send__(:define_method, method_name) do |*args, **kwargs, &block|
          if kwargs.empty?
            original_method.call(*args, &block)
          else
            original_method.call(*args, **kwargs, &block)
          end
        end
        eigenclass.__send__(original_visibility, method_name) if original_visibility != :public
      else
        eigenclass.__send__(:remove_method, method_name)
      end
    end
  end

  private

  def method_visibility(eigenclass, method_name)
    return :private if eigenclass.private_method_defined?(method_name)
    return :protected if eigenclass.protected_method_defined?(method_name)

    :public
  end

  def with_warnings_silenced
    previous_verbose = $VERBOSE
    $VERBOSE = nil
    yield
  ensure
    $VERBOSE = previous_verbose
  end
end

module Minitest
  class Test
    include TestStubHelper
  end
end
