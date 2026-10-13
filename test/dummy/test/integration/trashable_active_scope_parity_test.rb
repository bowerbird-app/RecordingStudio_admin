# frozen_string_literal: true

require "test_helper"

class TrashableActiveScopeParityTest < ActionDispatch::IntegrationTest
  test "trashable active scope matches legacy trashed_at nil filter for admin lookups" do
    assert_includes RecordingStudio::Recording.included_modules, RecordingStudioTrashable::RecordingScopes
    assert RecordingStudio::Recording.respond_to?(:recording_studio_trashable_active)

    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    kept = RecordingStudio::Recording.unscoped.recording_studio_trashable_active.find_by(
      recordable: admin_root
    )
    legacy = RecordingStudio::Recording.unscoped.find_by(
      recordable: admin_root,
      trashed_at: nil
    )

    assert_equal admin_root_recording, kept
    assert_equal legacy, kept
    assert_nil kept.trashed_at

    active_sql = RecordingStudio::Recording.unscoped.recording_studio_trashable_active.where(
      recordable: admin_root
    ).to_sql
    legacy_sql = RecordingStudio::Recording.unscoped.where(
      recordable: admin_root,
      trashed_at: nil
    ).to_sql

    assert_includes active_sql, '"trashed_at" IS NULL'
    assert_includes legacy_sql, '"trashed_at" IS NULL'
  end

  test "section recording resolver skips trashed section recordings" do
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

    resolver = RecordingStudioAdmin::SectionRecordingResolver.allocate
    found_kept = resolver.send(:find_recording, folder, root_recording, root_recording)
    found_trashed = resolver.send(:find_recording, trashed_folder, root_recording, root_recording)

    assert_equal kept, found_kept
    assert_nil found_trashed
  ensure
    Current.actor = previous_actor
  end
end
