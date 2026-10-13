# frozen_string_literal: true

require "test_helper"

class TrashableActiveScopeParityTest < ActionDispatch::IntegrationTest
  test "admin-root kept_sql matches main trashed_at nil filter" do
    assert RecordingStudio::Recording.respond_to?(:recording_studio_trashable_kept_sql)

    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)

    kept = RecordingStudio::Recording.where(
      RecordingStudio::Recording.recording_studio_trashable_kept_sql
    ).find_by(recordable: admin_root)
    legacy = RecordingStudio::Recording.find_by(
      recordable: admin_root,
      trashed_at: nil
    )

    assert_equal admin_root_recording, kept
    assert_equal legacy, kept
    assert_nil kept.trashed_at
  end

  test "real admin-root resolver matches main under trashed_at default_scope" do
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
    recording_class = RecordingStudio::Recording
    previous_default_scopes = recording_class.default_scopes.dup

    recording_class.class_eval do
      default_scope -> { where.not(trashed_at: nil) }
    end

    begin
      legacy = recording_class.find_by(recordable: admin_root, trashed_at: nil)
      kept = recording_class.where(recording_class.recording_studio_trashable_kept_sql)
                            .find_by(recordable: admin_root)
      active = recording_class.recording_studio_trashable_active.find_by(recordable: admin_root)
      configured = RecordingStudioAdmin.configuration.access_recording_resolver.call(nil)

      assert_nil legacy, "main admin-root lookup intersects host trashed_at default_scope"
      assert_nil kept, "kept_sql must preserve host trashed_at default_scope like main"
      assert_nil configured, "configured access_recording_resolver must match main"
      assert_equal legacy.nil?, kept.nil?
      assert_equal legacy.nil?, configured.nil?
      assert_not_nil active,
                     "recording_studio_trashable_active would unscope trashed_at and diverge from main"
    ensure
      recording_class.default_scopes.replace(previous_default_scopes)
    end
  end

  test "workspace stats scope matches main under trashed_at default_scope" do
    actor = User.find_or_create_by!(email: "trashable-stats-parity@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    previous_actor = Current.actor
    Current.actor = actor

    workspace = Workspace.create!(name: "Stats parity #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    folder = Folder.create!(name: "Stats folder #{SecureRandom.hex(4)}")
    RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording
    )

    context = Struct.new(:root_recording).new(root_recording)
    recording_class = RecordingStudio::Recording
    previous_default_scopes = recording_class.default_scopes.dup

    recording_class.class_eval do
      default_scope -> { where.not(trashed_at: nil) }
    end

    begin
      legacy = recording_class.where(
        root_recording_id: root_recording.id,
        trashed_at: nil,
        recordable_type: %w[Folder Page]
      ).where.not(id: root_recording.id)
      current = AdminScreens::WorkspaceStats.recordings_scope(context)
      active = recording_class.recording_studio_trashable_active.where(
        root_recording_id: root_recording.id,
        recordable_type: %w[Folder Page]
      ).where.not(id: root_recording.id)

      assert_equal 0, legacy.count
      assert_equal 0, current.count
      assert_operator active.count, :>, 0,
                      "chaining _active would drop the host trashed_at default_scope"
    ensure
      recording_class.default_scopes.replace(previous_default_scopes)
    end
  ensure
    Current.actor = previous_actor
  end

  test "section resolver kept_sql on unscoped matches main" do
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
      default_scope -> { where.not(trashed_at: nil) }
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
