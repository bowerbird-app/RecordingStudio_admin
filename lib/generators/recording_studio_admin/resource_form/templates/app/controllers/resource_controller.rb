# frozen_string_literal: true

class <%= controller_class_name %> < BaseController
  before_action :set_<%= singular_name %>
  before_action :authorize_<%= resource_key %>_admin_action!

<% if route_actions.include?("show") -%>
  def show
<% if route_actions.include?("edit") -%>
    @edit_<%= singular_name %>_action = resolve_<%= resource_key %>_admin_action(:edit)
<% end -%>
  end

<% end -%>
<% if route_actions.include?("edit") -%>
  def edit; end

<% end -%>
<% if route_actions.include?("update") -%>
  def update
    if perform_recording_studio_admin_action!("<%= resource_key %>", :edit, <%= instance_name %>, audit_action: :update) { <%= instance_name %>.update(<%= singular_name %>_params) }
      redirect_to recording_studio_admin_context.admin_screen_path("<%= screen_key %>")
    else
      render :edit, status: :unprocessable_entity
    end
  end

<% end -%>
  private

  def set_<%= singular_name %>
    <%= instance_name %> = <%= model_class_name %>.find(params[:id])
  end

  def authorize_<%= resource_key %>_admin_action!
    resource_action = action_name == "update" ? :edit : action_name
    RecordingStudioAdmin.authorize_resource!(
      key: "<%= resource_key %>",
      action: resource_action,
      context: recording_studio_admin_context,
      record: <%= instance_name %>,
      audit: true,
      audit_action: action_name
    )
  rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
    head :forbidden
  end

  def resolve_<%= resource_key %>_admin_action(action)
    RecordingStudioAdmin.authorize_resource!(
      key: "<%= resource_key %>",
      action: action,
      context: recording_studio_admin_context,
      record: <%= instance_name %>
    ).resolve(<%= instance_name %>, recording_studio_admin_context)
  rescue RecordingStudioAdmin::AuthorizationFailed, RecordingStudioAdmin::DefinitionNotFound
    nil
  end

  def <%= singular_name %>_params
    params.require(:<%= model_param_key %>).permit(<%= field_names.map { |field| ":#{field}" }.join(", ") %>)
  end
end