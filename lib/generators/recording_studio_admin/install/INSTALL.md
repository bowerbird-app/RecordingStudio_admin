RecordingStudioAdmin is installed.

Next steps:

1. Run `bin/rails generate recording_studio_admin:admin_root` if you want editable app-owned admin root scaffolding.
2. Ensure `RecordingStudioAccessible::Engine` and `RecordingStudioAdmin::Engine` are mounted.
3. Confirm `RecordingStudioAdmin.configuration.authentication_method` matches your host app authentication method. The default is `authenticate_user!`.
4. Configure `RecordingStudioAdmin.configuration.access_recording_resolver` so every mounted admin request resolves the mandatory `RecordingStudio::Recording` that owns the current admin screen context. RecordingStudioAdmin checks that recording with `RecordingStudioAccessible.authorized?` and fails closed with `403 Forbidden` when the recording is missing or the current actor cannot view it.
5. Register class-based sections and screens from an initializer or engine `config.to_prepare` block.
6. Rebuild Tailwind assets if the generator added source entries.
