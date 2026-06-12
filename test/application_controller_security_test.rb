# frozen_string_literal: true

require "test_helper"

class ApplicationControllerSecurityTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_engine_controller_has_fail_closed_authentication_hook
    source = File.read(File.join(ROOT, "app/controllers/recording_studio_admin/application_controller.rb"))

    assert_includes source, "before_action :authenticate_recording_studio_admin!"
    assert_includes source, "head :unauthorized"
    assert_includes source, "set_recording_studio_admin_current_actor"
  end
end
