# frozen_string_literal: true

class Stats::BaseController < Admin::BaseController
  private

  def recording_studio_admin_context
    @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
      params: params.to_unsafe_h,
      current_actor: current_user,
      controller: self,
      routes: self,
      view_context: view_context,
      surface: RecordingStudioAdmin.configuration.surface_for(:stats)
    )
  end

  def recording_studio_admin_access_recording
    current_root_recording
  end

  def page_nav_anchor_url(default: root_url)
    super
  end
end
