class HomeController < ApplicationController
  def index
    @current_root_recording = current_root_recording
    @admin_root_home = @current_root_recording&.recordable_type == "AdminRoot"
  end
end
