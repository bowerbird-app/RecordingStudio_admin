# frozen_string_literal: true

module Admin
  class UsersController < BaseController
    before_action :set_user
    before_action :authorize_users_admin_action!

    def show
      @edit_user_action = resolve_users_admin_action(:edit)
    end

    def edit; end

    def update
      if perform_recording_studio_admin_action!("users", :edit, @user, audit_action: :update) { @user.update(user_params) }
        redirect_to recording_studio_admin_context.admin_screen_path("users")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def flag_email
      perform_recording_studio_admin_action!("users", :flag_email, @user) do
        @user.update!(email: "flagged-#{@user.id}@example.com")
      end

      redirect_to recording_studio_admin_context.admin_screen_path("users")
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def authorize_users_admin_action!
      resource_action = action_name == "update" ? :edit : action_name
      RecordingStudioAdmin.authorize_resource!(
        key: "users",
        action: resource_action,
        context: recording_studio_admin_context,
        record: @user,
        audit: true,
        audit_action: action_name
      )
    rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
      head :forbidden
    end

    def resolve_users_admin_action(action)
      RecordingStudioAdmin.authorize_resource!(
        key: "users",
        action: action,
        context: recording_studio_admin_context,
        record: @user
      ).resolve(@user, recording_studio_admin_context)
    rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
      nil
    end

    def user_params
      params.require(:user).permit(:email)
    end
  end
end