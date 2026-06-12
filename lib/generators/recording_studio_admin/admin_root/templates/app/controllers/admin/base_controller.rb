# frozen_string_literal: true

class Admin::BaseController < ApplicationController
  layout "admin"

  before_action :authenticate_admin_user!
  before_action :authorize_admin_user!

  private

  def authenticate_admin_user!
    method_name = RecordingStudioAdmin.configuration.authentication_method
    return send(method_name) if method_name && respond_to?(method_name, true)

    head :unauthorized
  end

  def authorize_admin_user!
    return if performed?

    method_name = RecordingStudioAdmin.configuration.authorization_method
    return head :forbidden unless method_name && respond_to?(method_name, true)

    result = send(method_name)
    head :forbidden if result == false && !performed?
  end
end
