# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

find_or_record_child = lambda do |recordable, root_recording, parent_recording|
  RecordingStudio::Recording.find_by(
    root_recording: root_recording,
    parent_recording: parent_recording,
    recordable: recordable,
    trashed_at: nil
  ) || RecordingStudio.record!(
    action: "created",
    recordable: recordable,
    root_recording: root_recording,
    parent_recording: parent_recording
  ).recording
end

grant_admin_access = lambda do |recording, actor|
  next if RecordingStudioAccessible.role_for(actor: actor, recording: recording) == :admin

  result = RecordingStudioAccessible.grant_access(
    recording: recording,
    actor: actor,
    role: :admin,
    manager_actor: actor
  )

  raise "Failed to grant access: #{result.error}" if result.failure?
end

# Create the admin user
user = User.find_or_create_by!(email: "admin@admin.com") do |u|
  u.password = "Password"
  u.password_confirmation = "Password"
end

# Create the workspace recordables
workspace = Workspace.find_or_create_by!(name: "Studio Workspace")
accessible_workspace = Workspace.find_or_create_by!(name: "Client Workspace")
private_workspace = Workspace.find_or_create_by!(name: "Private Workspace")
folder = Folder.find_or_create_by!(name: "Product Docs")
page = Page.find_or_create_by!(title: "Getting Started")

previous_actor = Current.actor
Current.actor = user
previous_access_authorizer = RecordingStudioAccessible.configuration.access_management_authorizer
RecordingStudioAccessible.configuration.access_management_authorizer = ->(recording:, **) { recording.present? }

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = find_or_record_child.call(folder, root_recording, root_recording)

  find_or_record_child.call(page, root_recording, folder_recording)

  [ root_recording, accessible_root_recording, private_root_recording ].each do |recording|
    grant_admin_access.call(recording, user)
  end
ensure
  RecordingStudioAccessible.configuration.access_management_authorizer = previous_access_authorizer
  Current.actor = previous_actor
end

puts "Seeded: admin@admin.com / Password"
puts "Seeded: Workspace '#{workspace.name}' with root recording ##{root_recording.id}"
puts "Seeded: Workspace '#{accessible_workspace.name}' with root recording ##{accessible_root_recording.id}"
puts "Seeded: Workspace '#{private_workspace.name}' with root recording ##{private_root_recording.id}"
puts "Seeded: Folder '#{folder.name}' and page '#{page.title}'"

admin_root = AdminRoot.find_or_create_by!(name: "Admin")
previous_actor = Current.actor
Current.actor = user
previous_access_authorizer = RecordingStudioAccessible.configuration.access_management_authorizer
RecordingStudioAccessible.configuration.access_management_authorizer = ->(recording:, **) { recording.present? }
begin
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)
  grant_admin_access.call(admin_root_recording, user)

  admin_summary_section = AdminSummarySection.find_or_create_by!(key: "root") do |record|
    record.name = "Admin summary"
  end
  find_or_record_child.call(admin_summary_section, admin_root_recording, admin_root_recording)
ensure
  RecordingStudioAccessible.configuration.access_management_authorizer = previous_access_authorizer
  Current.actor = previous_actor
end

paths = [ "/api/projects", "/api/uploads", "/api/search", "/api/reports" ]
methods = %w[GET POST PATCH DELETE]
statuses = [ 200, 200, 201, 204, 400, 404, 422, 500 ]
120.times do |index|
  ApiRequest.find_or_create_by!(path: paths[index % paths.size], method: methods[index % methods.size], created_at: index.hours.ago) do |record|
    record.status = statuses[index % statuses.size]
    record.latency_ms = 40 + (index * 17) % 900
    record.updated_at = record.created_at
  end
end

error_classes = %w[TimeoutError ValidationError NotFoundError IntegrationError]
40.times do |index|
  ApiError.find_or_create_by!(message: "Example failure #{index}", created_at: index.hours.ago) do |record|
    record.error_class = error_classes[index % error_classes.size]
    record.path = paths[index % paths.size]
    record.status = [ 400, 404, 422, 500 ][index % 4]
    record.updated_at = record.created_at
  end
end

actions = %w[signed_in exported_report updated_settings invited_user]
80.times do |index|
  UserActivity.find_or_create_by!(email: "user#{index % 12}@example.com", action: actions[index % actions.size], created_at: index.hours.ago) do |record|
    record.status = index.even? ? "success" : "review"
    record.updated_at = record.created_at
  end
end

queues = %w[default mailers imports critical]
70.times do |index|
  BackgroundJobRun.find_or_create_by!(job_class: "AdminJob#{index % 8}", queue: queues[index % queues.size], created_at: index.hours.ago) do |record|
    record.status = index % 9 == 0 ? "failed" : "completed"
    record.duration_ms = 100 + (index * 23) % 2_000
    record.updated_at = record.created_at
  end
end

puts "Seeded RecordingStudioAdmin demo data and admin root with admin access grants"
