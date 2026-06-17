# frozen_string_literal: true

module Admin
  class UserActivitiesController < BaseController
    def destroy
      UserActivity.find(params[:id]).destroy!

      redirect_back fallback_location: root_path, status: :see_other
    end
  end
end
