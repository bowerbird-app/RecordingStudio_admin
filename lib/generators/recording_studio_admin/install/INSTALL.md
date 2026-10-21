RecordingStudioAdmin is installed.

Next steps:

1. Run `bin/rails generate recording_studio_admin:admin_root` if you want editable app-owned admin root scaffolding.
2. Pin `recording_studio_logs` to GitHub tag `v0.5.0` and run `bin/rails generate recording_studio_logs:migrations` if Logs run tables are not already present. Existing hosts also run `bin/rails generate recording_studio_admin:logs`, then `bin/rails db:migrate`.
3. Leave `config.logs_summaries_enabled` false unless you have rebuilt `admin/audit_counts`. Activity logs keep reading raw audit rows.
4. Ensure `RecordingStudioAccessible::Engine` is mounted and `recording_studio_admin_for` declares your admin surface.
5. Confirm `RecordingStudioAdmin.configuration.authentication_method` matches your host app authentication method. The default is `authenticate_user!`.
6. Configure `RecordingStudioAdmin.configuration.access_recording_resolver` so every mounted admin request resolves the mandatory `RecordingStudio::Recording` that owns the current admin screen context. RecordingStudioAdmin checks that recording with `RecordingStudioAccessible.authorized?` and fails closed with `403 Forbidden` when the recording is missing or the current actor cannot view it.
7. Put class-based sections and screens in `app/admin` capability folders, then register them from an initializer or engine `config.to_prepare` block.
8. When a registered resource needs a standard host-owned show/edit/update flow, run `bin/rails generate recording_studio_admin:resource_form users --model=User --section=users --fields=email:email`.
9. When that resource later needs custom member actions such as `flag_email`, run `bin/rails generate recording_studio_admin:resource_action users flag_email --model=User --section=users`.
10. Rebuild Tailwind assets if the generator added source entries.
