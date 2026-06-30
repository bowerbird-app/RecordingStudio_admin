# frozen_string_literal: true

require "test_helper"

class <%= namespace_name.camelize %>::<%= route_resource_name.camelize %><%= normalized_action_name.camelize %>Test < ActionDispatch::IntegrationTest
  test <%= "#{normalized_action_name} requires #{resource_key}.#{normalized_action_name} authorization".inspect %> do
    skip "Replace with an app-specific integration or controller test that signs in an actor and asserts #{resource_key}.#{normalized_action_name} authorization"
  end

  test <%= "#{normalized_action_name} performs the expected mutation".inspect %> do
    skip "Replace with an app-specific integration or controller test that asserts the #{normalized_action_name} mutation and redirect"
  end
end