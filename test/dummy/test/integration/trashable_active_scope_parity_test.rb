# frozen_string_literal: true

require "test_helper"

class TrashableActiveScopeParityTest < ActionDispatch::IntegrationTest
  test "admin-root active scope matches main without adding unscoped" do
    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioTrashable::RecordingScopes
    assert RecordingStudio::Recording.respond_to?(:recording_studio_trashable_active)

    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)

    kept = RecordingStudio::Recording.recording_studio_trashable_active.find_by(
      recordable: admin_root
    )
    legacy = RecordingStudio::Recording.find_by(
      recordable: admin_root,
      trashed_at: nil
    )

    assert_equal admin_root_recording, kept
    assert_equal legacy, kept
    assert_nil kept.trashed_at
  end

  test "admin-root lookup stays identical to main under a host default scope" do
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    other_workspace = Workspace.create!(name: "Default scope decoy #{SecureRandom.hex(4)}")
    other_recording = RecordingStudio.root_recording_for(other_workspace)
    recording_class = RecordingStudio::Recording
    previous_default_scopes = recording_class.default_scopes.dup

    recording_class.class_eval do
      default_scope -> { where(id: other_recording.id) }
    end

    begin
      legacy = recording_class.find_by(recordable: admin_root, trashed_at: nil)
      kept = recording_class.recording_studio_trashable_active.find_by(recordable: admin_root)
      wrongly_unscoped = recording_class.unscoped.recording_studio_trashable_active.find_by(
        recordable: admin_root
      )

      assert_nil legacy, "main admin-root lookup respects host default_scope"
      assert_nil kept, "Trashable active must use the same base relation as main"
      assert_equal admin_root_recording, wrongly_unscoped,
                   "adding unscoped would diverge from main under a host default_scope"
      assert_equal legacy.nil?, kept.nil?
    ensure
      recording_class.default_scopes.replace(previous_default_scopes)
    end
  end

  test "section resolver keeps main unscoped base and matches trashed_at nil" do
    actor = User.find_or_create_by!(email: "trashable-parity@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    previous_actor = Current.actor
    Current.actor = actor

    workspace = Workspace.create!(name: "Trashable parity workspace #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.create!(name: "Parity folder #{SecureRandom.hex(4)}")

    kept = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording
    ).recording

    trashed_folder = Folder.create!(name: "Trashed parity folder #{SecureRandom.hex(4)}")
    trashed = RecordingStudio.record!(
      action: "created",
      recordable: trashed_folder,
      root_recording: root_recording,
      parent_recording: root_recording
    ).recording
    trashed.update_columns(trashed_at: Time.current, updated_at: Time.current)

    recording_class = RecordingStudio::Recording
    previous_default_scopes = recording_class.default_scopes.dup
    recording_class.class_eval do
      default_scope -> { where(id: trashed.id) }
    end

    begin
      resolver = RecordingStudioAdmin::SectionRecordingResolver.allocate
      found_kept = resolver.send(:find_recording, folder, root_recording, root_recording)
      found_trashed = resolver.send(:find_recording, trashed_folder, root_recording, root_recording)
      legacy_kept = recording_class.unscoped.find_by(
        root_recording: root_recording,
        parent_recording: root_recording,
        recordable: folder,
        trashed_at: nil
      )

      assert_equal kept, found_kept
      assert_equal legacy_kept, found_kept
      assert_nil found_trashed
    ensure
      recording_class.default_scopes.replace(previous_default_scopes)
    end
  ensure
    Current.actor = previous_actor
  end
end
