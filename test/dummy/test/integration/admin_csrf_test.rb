# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminCsrfTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  test "a tokenless post is rejected when forgery protection is on" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true

    with_routing do |routes|
      routes.draw do
        post "/admin/csrf_probe", to: "recording_studio_admin/sections#index"
      end

      post "/admin/csrf_probe"
    end

    assert_response :unprocessable_entity
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  test "engine pages send the csrf token when forgery protection is on" do
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    sign_in_admin_user

    get "/admin/screens/api_requests"

    assert_response :success
    assert_includes response.body, 'name="csrf-token"'

    get "/admin/screens/api_requests/table", params: { anchor_url: "/" }

    assert_response :success
    assert_includes response.body, 'name="authenticity_token"'
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end

  private

  def sign_in_admin_user
    user = User.find_or_create_by!(email: "admin-csrf@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    grant_admin_access_for_test!(recording: create_root_recording_for_test!(admin_root), actor: user)
    sign_in user
  end
end
