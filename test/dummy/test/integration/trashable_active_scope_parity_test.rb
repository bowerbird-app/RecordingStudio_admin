# frozen_string_literal: true

require "test_helper"

class TrashableActiveScopeParityTest < ActionDispatch::IntegrationTest
  include DummyAccessTestHelpers

  test "admin-root kept matches a nil trashed_at lookup" do
    assert RecordingStudio::Recording.respond_to?(:kept)
    assert_match(/trashed_at IS NULL/, RecordingStudio.kept_sql("child_recordings"))

    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)

    kept = RecordingStudio::Recording.kept.find_by(recordable: admin_root)
    legacy = RecordingStudio::Recording.find_by(recordable: admin_root, trashed_at: nil)

    assert_equal admin_root_recording, kept
    assert_equal legacy, kept
    assert_nil kept.trashed_at
  end

  test "real admin-root resolver keeps a host default scope" do
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    recording_class = RecordingStudio::Recording
    previous_default_scopes = recording_class.default_scopes.dup

    recording_class.class_eval do
      default_scope -> { where.not(trashed_at: nil) }
    end

    begin
      kept = recording_class.kept.find_by(recordable: admin_root)
      unscoped_kept = recording_class.unscoped.kept.find_by(recordable: admin_root)
      configured = RecordingStudioAdmin.configuration.access_recording_resolver.call(nil)

      assert_nil kept, "kept must intersect a host trashed_at default scope"
      assert_nil configured, "configured access_recording_resolver must match kept"
      assert_equal admin_root_recording, unscoped_kept
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
    grant_admin_access_for_test!(recording: root_recording, actor: actor)
    folder = Folder.create!(name: "Stats folder #{SecureRandom.hex(4)}")
    RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
    )

    context = Struct.new(:root_recording).new(root_recording)
    recording_class = RecordingStudio::Recording
    previous_default_scopes = recording_class.default_scopes.dup

    recording_class.class_eval do
      default_scope -> { where.not(trashed_at: nil) }
    end

    begin
      kept = recording_class.kept.where(
        root_recording_id: root_recording.id,
        recordable_type: %w[Folder Page]
      ).where.not(id: root_recording.id)
      current = AdminScreens::WorkspaceStats.recordings_scope(context)
      unscoped_kept = recording_class.unscoped.kept.where(
        root_recording_id: root_recording.id,
        recordable_type: %w[Folder Page]
      ).where.not(id: root_recording.id)

      assert_equal 0, kept.count
      assert_equal 0, current.count
      assert_operator unscoped_kept.count, :>, 0,
                      "unscoped.kept drops the host default scope; the stats screen must not"
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
    grant_admin_access_for_test!(recording: root_recording, actor: actor)
    folder = Folder.create!(name: "Parity folder #{SecureRandom.hex(4)}")

    kept = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
    ).recording

    trashed_folder = Folder.create!(name: "Trashed parity folder #{SecureRandom.hex(4)}")
    trashed = RecordingStudio.record!(
      action: "created",
      recordable: trashed_folder,
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
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
      legacy_kept = recording_class.unscoped.kept.find_by(
        root_recording: root_recording,
        parent_recording: root_recording,
        recordable: folder
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

  # Kills "drop trash filter from initializer" — without kept_sql the trashed
  # admin-root recording would still resolve.
  test "configured access resolver excludes a trashed admin-root recording" do
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    admin_root_recording = RecordingStudio.root_recording_for(admin_root)
    admin_root_recording.update_columns(trashed_at: Time.current, updated_at: Time.current)

    begin
      unfiltered = RecordingStudio::Recording.find_by(recordable: admin_root)
      configured = RecordingStudioAdmin.configuration.access_recording_resolver.call(nil)

      assert_equal admin_root_recording, unfiltered,
                   "setup: unfiltered find must see the trashed admin-root recording"
      assert_nil configured,
                 "access_recording_resolver must apply kept_sql (removing it would return the trashed row)"
    ensure
      admin_root_recording.update_columns(trashed_at: nil, updated_at: Time.current)
    end
  end

  # Kills "drop trash filter from stats screen" — without kept_sql a trashed
  # folder under the root would remain in the scope.
  test "workspace stats scope excludes trashed folder recordings" do
    actor = User.find_or_create_by!(email: "trashable-stats-filter@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    previous_actor = Current.actor
    Current.actor = actor

    workspace = Workspace.create!(name: "Stats filter #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: actor)
    folder = Folder.create!(name: "Trashed stats folder #{SecureRandom.hex(4)}")
    folder_recording = RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
    ).recording
    folder_recording.update_columns(trashed_at: Time.current, updated_at: Time.current)

    context = Struct.new(:root_recording).new(root_recording)
    unfiltered = RecordingStudio::Recording.where(
      root_recording_id: root_recording.id,
      recordable_type: %w[Folder Page]
    ).where.not(id: root_recording.id)
    current = AdminScreens::WorkspaceStats.recordings_scope(context)

    assert_includes unfiltered.pluck(:id), folder_recording.id,
                    "setup: unfiltered scope must include the trashed folder"
    refute_includes current.pluck(:id), folder_recording.id,
                    "workspace stats must apply kept_sql (removing it would keep the trashed folder)"
  ensure
    Current.actor = previous_actor
  end

  test "seeds find_or_record_child uses kept on the default relation" do
    seeds = File.read(Rails.root.join("db/seeds.rb"))

    assert_includes seeds, "RecordingStudio::Recording.kept.find_by"
    refute_includes seeds, "recording_studio_trashable_"
    refute_includes seeds, "unscoped"
    assert_includes seeds, "actor: actor"
    refute_includes seeds, "allow_unauthorized_writes"

    actor = User.find_or_create_by!(email: "trashable-seeds-parity@example.com") do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    previous_actor = Current.actor
    Current.actor = actor

    workspace = Workspace.create!(name: "Seeds parity #{SecureRandom.hex(4)}")
    root_recording = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root_recording, actor: actor)
    folder = Folder.create!(name: "Seeds folder #{SecureRandom.hex(4)}")
    RecordingStudio.record!(
      action: "created",
      recordable: folder,
      root_recording: root_recording,
      parent_recording: root_recording,
      actor: actor
    )

    recording_class = RecordingStudio::Recording
    previous_default_scopes = recording_class.default_scopes.dup
    recording_class.class_eval do
      default_scope -> { where.not(trashed_at: nil) }
    end

    begin
      seed_style = recording_class.kept.find_by(
        root_recording: root_recording,
        parent_recording: root_recording,
        recordable: folder
      )
      unscoped_style = recording_class.unscoped.kept.find_by(
        root_recording: root_recording,
        parent_recording: root_recording,
        recordable: folder
      )

      assert_nil seed_style, "seeds kept must intersect a host trashed_at default scope"
      assert_not_nil unscoped_style
    ensure
      recording_class.default_scopes.replace(previous_default_scopes)
    end
  ensure
    Current.actor = previous_actor
  end

  test "initializer and workspace stats sources keep kept_sql trash filter" do
    initializer = File.read(Rails.root.join("config/initializers/recording_studio_admin.rb"))
    screen = File.read(Rails.root.join("app/admin/stats/workspace_stats/screen.rb"))

    assert_includes initializer, "RecordingStudio::Recording.kept.find_by"
    refute_includes initializer, "recording_studio_trashable_"
    assert_includes screen, "RecordingStudio::Recording.kept.where"
    refute_includes screen, "recording_studio_trashable_"
  end
end
