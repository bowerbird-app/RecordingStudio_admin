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

bootstrap_owner_access = lambda do |recording, actor|
  current_role = RecordingStudioAccessible.role_for(actor: actor, recording: recording)
  next if current_role == :admin

  result = RecordingStudioAccessible.bootstrap_owner_access!(
    recording: recording,
    actor: actor
  )

  raise "Failed to bootstrap owner access: #{result.error}" if result.failure?
end

set_timestamps = lambda do |record, timestamp|
  next unless record.respond_to?(:created_at) && record.persisted?

  record.class.where(id: record.id).update_all(created_at: timestamp, updated_at: timestamp)
end

record_seed_child = lambda do |recordable, root_recording, parent_recording, created_at:|
  recording = find_or_record_child.call(recordable, root_recording, parent_recording)
  set_timestamps.call(recordable, created_at)
  set_timestamps.call(recording, created_at)
  recording
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

begin
  # Create the root recording
  root_recording = RecordingStudio.root_recording_for(workspace)
  accessible_root_recording = RecordingStudio.root_recording_for(accessible_workspace)
  private_root_recording = RecordingStudio.root_recording_for(private_workspace)

  folder_recording = record_seed_child.call(folder, root_recording, root_recording, created_at: 6.weeks.ago.change(hour: 9))
  record_seed_child.call(page, root_recording, folder_recording, created_at: 6.weeks.ago.change(hour: 11))

  {
    root_recording => {
      "Analytics" => [ "Weekly KPI Dashboard", "Revenue Snapshot" ],
      "Marketing" => [ "Campaign Brief", "Launch Checklist" ],
      "Onboarding" => [ "Support Runbook", "Welcome Guide" ]
    },
    accessible_root_recording => {
      "Client Reports" => [ "Q1 Summary", "Renewal Notes" ],
      "Operations" => [ "Escalation Paths", "Status Update" ]
    }
  }.each_with_index do |(current_root_recording, folders), root_index|
    folders.each_with_index do |(folder_name, page_titles), folder_index|
      folder_created_at = (5.weeks - (root_index * 3 + folder_index).days).ago.change(hour: 10)
      content_folder = Folder.find_or_create_by!(name: folder_name)
      content_folder_recording = record_seed_child.call(
        content_folder,
        current_root_recording,
        current_root_recording,
        created_at: folder_created_at
      )

      page_titles.each_with_index do |title, page_index|
        content_page = Page.find_or_create_by!(title: title)
        record_seed_child.call(
          content_page,
          current_root_recording,
          content_folder_recording,
          created_at: folder_created_at + (page_index + 1).days
        )
      end
    end
  end

  nested_folder = Folder.find_or_create_by!(name: "Analytics Experiments")
  nested_folder_recording = record_seed_child.call(
    nested_folder,
    root_recording,
    Folder.find_by!(name: "Analytics").then { |record| RecordingStudio::Recording.find_by!(recordable: record, root_recording: root_recording) },
    created_at: 10.days.ago.change(hour: 13)
  )
  nested_page = Page.find_or_create_by!(title: "Experiment Backlog")
  record_seed_child.call(
    nested_page,
    root_recording,
    nested_folder_recording,
    created_at: 9.days.ago.change(hour: 15)
  )

  [ root_recording, accessible_root_recording, private_root_recording ].each do |recording|
    bootstrap_owner_access.call(recording, user)
  end
ensure
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
begin
  admin_root_recording = RecordingStudio.root_recording_for(admin_root)
  bootstrap_owner_access.call(admin_root_recording, user)

  admin_section = AdminSection.find_or_create_by!(key: "root") do |record|
    record.name = "Admin section"
  end
  find_or_record_child.call(admin_section, admin_root_recording, admin_root_recording)
ensure
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

admin_audit_templates = [
  {
    resource_key: "users",
    action_key: "edit",
    http_method: "PATCH",
    destructive: false,
    required_role: "editor",
    blast_radius: "workspace",
    surface_key: "users"
  },
  {
    resource_key: "users",
    action_key: "flag_email",
    http_method: "POST",
    destructive: false,
    required_role: "editor",
    blast_radius: "workspace",
    surface_key: "users"
  },
  {
    resource_key: "pages",
    action_key: "destroy",
    http_method: "DELETE",
    destructive: true,
    required_role: "admin",
    blast_radius: "workspace",
    surface_key: "content"
  },
  {
    resource_key: "api_requests",
    action_key: "export",
    http_method: "POST",
    destructive: false,
    required_role: "analyst",
    blast_radius: "site",
    surface_key: "api"
  },
  {
    resource_key: "background_jobs",
    action_key: "retry",
    http_method: "POST",
    destructive: false,
    required_role: "admin",
    blast_radius: "site",
    surface_key: "jobs"
  }
]

72.times do |index|
  template = admin_audit_templates[index % admin_audit_templates.size]
  outcome = case index % 12
  when 0, 5, 9
    "validation_failed"
  when 3, 11
    "failed"
  when 7
    "denied"
  else
    "performed"
  end
  occurred_at = (18.days.ago + (index * 6).hours).change(min: (index * 7) % 60)

  log = AdminAuditLog.find_or_initialize_by(event_id: format("seed-admin-audit-%03d", index + 1))
  log.assign_attributes(
    resource_key: template[:resource_key],
    action_key: template[:action_key],
    outcome: outcome,
    actor_type: "User",
    actor_id: ((index % 6) + 1).to_s,
    record_type: template[:resource_key].singularize.camelize,
    record_id: (1_000 + index).to_s,
    access_recording_id: nil,
    surface_key: template[:surface_key],
    http_method: template[:http_method],
    destructive: template[:destructive],
    required_role: template[:required_role],
    blast_radius: template[:blast_radius],
    request_id: format("req-seed-%04d", index + 1),
    ip_address: "192.168.10.#{(index % 40) + 10}",
    user_agent: "DummyAdminSeed/1.0",
    metadata: {
      source: "db/seeds.rb",
      changed_fields: index.even? ? [ "email" ] : [ "status", "role" ],
      note: "Demo audit entry #{index + 1}"
    },
    error_class: (outcome == "failed" ? "StandardError" : nil),
    error_message: (
      case outcome
      when "failed"
        "Simulated processing failure for demo"
      when "validation_failed"
        "Validation failed: email is invalid"
      when "denied"
        "Policy denied this action"
      end
    ),
    recording_studio_event_id: nil,
    occurred_at: occurred_at
  )
  log.save!
end

puts "Seeded 72 admin audit log events for admin activity demos"

puts "Seeded RecordingStudioAdmin demo data and admin root with admin access grants"
