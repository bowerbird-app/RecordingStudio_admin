# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class ScopedLibraryScreenTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include DummyAccessTestHelpers

  setup do
    @previous_scope_limit = RecordingStudioAdmin.configuration.max_scoped_recordings
  end

  teardown do
    RecordingStudioAdmin.configuration.max_scoped_recordings = @previous_scope_limit
  end

  test "library screen requires a signed in viewer and access to the workspace" do
    get "/stats/screens/library", params: { reach: "subtree" }, xhr: true

    assert_response :unauthorized

    sign_in_user("library-no-access@example.com")

    get "/stats/screens/library", params: { reach: "subtree" }

    assert_response :forbidden
  end

  test "subtree lists kept items under the workspace and ignores widening params" do
    user = sign_in_user("library-subtree@example.com")
    tree = build_tree(user)
    switch_to_workspace_root!(tree.fetch(:root))

    get "/stats/screens/library", params: { reach: "subtree" }

    assert_response :success
    assert_includes response.body, "Who"
    assert_includes response.body, "Reach"
    assert_includes response.body, "Kind"
    assert_includes response.body, "Everything under it"
    assert_includes response.body, "stylesheet"

    get "/stats/screens/library/table", params: widening_params(tree)

    assert_response :success
    assert_includes response.body, "Atlas Notes"
    assert_includes response.body, "Zephyr Brief"
    refute_includes response.body, "Atlas Trash"
    refute_includes response.body, "Buried Note"
    refute_includes response.body, tree.fetch(:foreign_title)

    get "/stats/screens/library/table_count", params: { reach: "subtree", recordable_type: "Page" }

    assert_response :success
    assert_includes response.body, "2 rows"

    get "/stats/screens/library/table", params: { reach: "subtree", person: "Atlas" }

    assert_response :success
    assert_includes response.body, "Atlas Notes"
    assert_includes response.body, "Atlas Brief"
    refute_includes response.body, "Zephyr Brief"

    get "/stats/screens/library/table_count", params: { reach: "self" }

    assert_response :success
    assert_includes response.body, "0 rows"
  end

  test "chart and table frames use the same subtree" do
    user = sign_in_user("library-frames@example.com")
    tree = build_tree(user)
    switch_to_workspace_root!(tree.fetch(:root))

    get "/stats/screens/library/table", params: { reach: "subtree" }
    assert_response :success
    assert_includes response.body, "Atlas Brief"

    get "/stats/screens/library/chart", params: { reach: "subtree" }
    assert_response :success
    assert_includes response.body, "Added over time"

    get "/stats/screens/library/table_count", params: { reach: "subtree" }
    assert_response :success
    assert_includes response.body, "4 rows"
  end

  test "a sibling kit does not leak and an undeclared screen ignores scope params" do
    user = sign_in_user("library-sibling@example.com")
    tree = build_tree(user)
    switch_to_workspace_root!(tree.fetch(:root))
    context = RecordingStudioAdmin::Context.new(
      params: {
        "reach" => "subtree",
        "recordable_type" => "Workspace",
        "recording_id" => tree.fetch(:zephyr_page).id,
        "root_recording_id" => tree.fetch(:foreign_root).id,
        "access_recording_id" => tree.fetch(:foreign_page).id
      },
      controller: access_controller(tree.fetch(:atlas_folder)),
      surface: RecordingStudioAdmin.configuration.surface_for(:stats),
      screen_definition: AdminScreens::Library,
      current_actor: user
    )

    ids = context.scoped_recording_ids

    assert_includes ids, tree.fetch(:atlas_folder).id
    assert_includes ids, tree.fetch(:atlas_page).id
    refute_includes ids, tree.fetch(:zephyr_folder).id
    refute_includes ids, tree.fetch(:zephyr_page).id
    refute_includes ids, tree.fetch(:trashed_folder).id
    refute_includes ids, tree.fetch(:buried_page).id
    refute_includes ids, tree.fetch(:foreign_page).id

    get "/stats/screens/workspace_stats/table_count", params: { reach: "subtree" }
    scoped_count = response.body
    get "/stats/screens/workspace_stats/table_count", params: {
      reach: "subtree",
      recordable_type: "NotAType",
      recording_id: tree.fetch(:foreign_page).id
    }

    assert_response :success
    assert_equal scoped_count, response.body
    refute_includes response.body, tree.fetch(:foreign_title)
  end

  test "the stats section links into the library and unlabeled filters still humanize" do
    user = sign_in_user("library-link@example.com")
    tree = build_tree(user)
    switch_to_workspace_root!(tree.fetch(:root))

    get "/stats/sections/stats"

    assert_response :success
    assert_includes response.body, "Browse the library"
    assert_includes response.body, "/stats/screens/library?reach=subtree"

    get "/stats/screens/workspace_stats"

    assert_response :success
    assert_includes response.body, "Group by"
  end

  test "a subtree over the cap fails closed" do
    user = sign_in_user("library-cap@example.com")
    tree = build_tree(user)
    switch_to_workspace_root!(tree.fetch(:root))
    RecordingStudioAdmin.configuration.max_scoped_recordings = 1

    get "/stats/screens/library/table", params: { reach: "subtree" }

    assert_response :unprocessable_entity
    assert_includes response.body, "Too many items under this spot"
    assert_includes response.body, "The limit is 1"
  end

  private

  def sign_in_user(email)
    user = User.find_or_create_by!(email: email) do |record|
      record.password = "Password123!"
      record.password_confirmation = "Password123!"
    end
    sign_in user
    user
  end

  def switch_to_workspace_root!(workspace_root_recording)
    patch "/recording_studio_root_switchable/v1/root_switch", params: {
      scope: "all_workspaces",
      root_switch: {
        root_recording_id: workspace_root_recording.id,
        return_to: "/"
      }
    }
    follow_redirect!
  end

  def build_tree(user)
    token = SecureRandom.hex(4)
    workspace = Workspace.create!(name: "Library #{token}")
    root = RecordingStudio.root_recording_for(workspace)
    grant_admin_access_for_test!(recording: root, actor: user)
    atlas_folder = record_child!(Folder.create!(name: "Atlas Notes #{token}"), root, root, user)
    atlas_page = record_child!(Page.create!(title: "Atlas Brief #{token}"), root, atlas_folder, user)
    zephyr_folder = record_child!(Folder.create!(name: "Zephyr Kit #{token}"), root, root, user)
    zephyr_page = record_child!(Page.create!(title: "Zephyr Brief #{token}"), root, zephyr_folder, user)
    trashed_folder = record_child!(Folder.create!(name: "Atlas Trash #{token}"), root, root, user)
    buried_page = record_child!(Page.create!(title: "Buried Note #{token}"), root, trashed_folder, user)
    trashed_folder.update_columns(trashed_at: Time.current, updated_at: Time.current)
    foreign_root_recordable = Workspace.create!(name: "Foreign #{token}")
    foreign_root = RecordingStudio.root_recording_for(foreign_root_recordable)
    grant_admin_access_for_test!(recording: foreign_root, actor: user)
    foreign_title = "Foreign Page #{token}"
    foreign_page = record_child!(Page.create!(title: foreign_title), foreign_root, foreign_root, user)

    {
      root: root,
      atlas_folder: atlas_folder,
      atlas_page: atlas_page,
      zephyr_folder: zephyr_folder,
      zephyr_page: zephyr_page,
      trashed_folder: trashed_folder,
      buried_page: buried_page,
      foreign_root: foreign_root,
      foreign_page: foreign_page,
      foreign_title: foreign_title,
      token: token
    }
  end

  def widening_params(tree)
    {
      reach: "subtree",
      recordable_type: "Folder' OR '1'='1",
      recording_id: tree.fetch(:foreign_page).id,
      root_recording_id: tree.fetch(:foreign_root).id,
      access_recording_id: tree.fetch(:foreign_page).id
    }
  end

  def record_child!(recordable, root_recording, parent_recording, actor)
    previous_actor = Current.actor
    Current.actor = actor
    RecordingStudio.record!(
      action: "created",
      recordable: recordable,
      root_recording: root_recording,
      parent_recording: parent_recording,
      actor: actor
    ).recording
  ensure
    Current.actor = previous_actor
  end

  def access_controller(recording)
    controller = Object.new
    controller.define_singleton_method(:current_root_recording) { recording }
    controller
  end
end
