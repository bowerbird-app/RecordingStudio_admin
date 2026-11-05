# frozen_string_literal: true

require "test_helper"

class AuthorizeWriteTest < ActiveSupport::TestCase
  include DummyAccessTestHelpers

  test "dummy authorize_write is configured and is not actor presence" do
    initializer = File.read(Rails.root.join("config/initializers/recording_studio.rb"))

    assert_includes initializer, "config.authorize_write"
    assert_includes initializer, "RecordingStudioAccessible.authorized?"
    refute_match(/authorize_write\s*=\s*->\(actor:, \*\*\) \{ actor\.present\? \}/, initializer)
    refute_includes initializer, "allow_unauthorized_writes = true"
  end

  test "dummy authorize_write requires a persisted user with accessible edit on the root" do
    authorizer = RecordingStudio.configuration.authorize_write

    refute_nil authorizer

    actor = User.find_or_create_by!(email: "dummy-write-authorizer@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    workspace = Workspace.create!(name: "Write policy #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.new(name: "Write policy folder")

    refute authorizer.call(actor: nil, root_recording: root_recording, recordable: folder)
    refute authorizer.call(actor: actor, root_recording: root_recording, recordable: folder)

    grant_admin_access_for_test!(recording: root_recording, actor: actor)

    assert authorizer.call(actor: actor, root_recording: root_recording, recordable: folder)
  end

  test "child writes fail without an actor even when the authorizer is set" do
    workspace = Workspace.create!(name: "Missing actor #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    previous_actor = RecordingStudio.configuration.actor
    RecordingStudio.configuration.actor = -> {}

    begin
      assert_raises(RecordingStudio::AuthorizationError, RecordingStudio::ActorRequired) do
        RecordingStudio.record!(
          action: "created",
          recordable: Folder.new(name: "No actor folder"),
          root_recording: root_recording,
          parent_recording: root_recording,
          actor: nil
        )
      end
    ensure
      RecordingStudio.configuration.actor = previous_actor
    end
  end
end
