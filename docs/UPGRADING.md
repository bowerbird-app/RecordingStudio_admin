# Upgrading RecordingStudioAdmin

## Upgrading to 2.0.0

Admin `2.0.0` is a clean break onto Accessible `~> 0.6` and RecordingStudio `~> 4.1`. Hosts still on Accessible `0.3` (or RecordingStudio 3.x) must stay on Admin `1.2.x` until that stack is upgraded.

Section, screen, widget, and resource definition APIs are unchanged. The breaking work is the platform floor, Accessible enablement, and first-staff grants.

### 1. Upgrade the platform gems first

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.1.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.6.1"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.129"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin" # 2.0.0
```

This gem depends on `recording_studio_accessible ~> 0.6` (which requires RecordingStudio `~> 4.1`) and `flat_pack ~> 0.1.129`. Bundler will reject Admin `2.0.0` next to Accessible `~> 0.3`.

If you are coming from RecordingStudio 3.x, run `bin/rails generate recording_studio:migrations` (or install the harden-indexes migration) and `db:migrate` before mounting admin.

### 2. Replace the old Accessible mixin

`AllowsAccessibleChildren` and `recording_studio_accessible_children` are gone. Admin no longer backfills them.

```ruby
# Before
include RecordingStudioAccessible::AllowsAccessibleChildren
recording_studio_accessible_children :access

# After
RecordingStudio.enable_capability(:accessible, on: self)
```

Enable `:accessible` on every recordable that should hold grants, including `AdminRoot` and any nested admin section recordable that owns access children.

Keep **AdminRoot owned** (`shared: false`). Do not declare it as a shared root. Accessible refuses new grants on shared roots; staff access belongs on the owned admin root.

Re-run `bin/rails generate recording_studio_admin:admin_root` only if you want the updated template. Existing hosts can change the model by hand.

### 3. Configure grant actors and first staff

Accessible `0.5+` fails closed when `access_actor_types` is blank:

```ruby
RecordingStudioAccessible.configure do |config|
  config.access_actor_types = ["User"]
end
```

For the first `:admin` on an empty owned admin root, use Accessible bootstrap (no ENV authorizer, no `AccessCreationContext.allow`):

```ruby
RecordingStudioAccessible.bootstrap_owner_access!(
  recording: RecordingStudio.root_recording_for(admin_root),
  actor: first_staff_user
)
```

Use `grant_access` for later invites. Fail-closed admin checks are unchanged: missing auth → `401`; missing access recording or Accessible denial → `403`.

### 4. Optional CSV export

Admin still gates export UI behind `defined?(RecordingStudioExportable)`. Dummy no longer ships Exportable because Exportable `0.2.0` requires RecordingStudio `~> 4.2`. Hosts that stay on RS `4.1` can omit Exportable; hosts on RS `4.2` can add Exportable `0.2.0` and enable it with `include RecordingStudio::Capabilities::Exportable.to(...)`.

### What this release does not change

- `recording_studio_admin_for`, surfaces, `AllowsAdminSections`
- Section / screen / widget / resource Ruby APIs
- `RecordingStudioAccessible.authorized?` as the admin gate

### Downstream gems

Admin `2.0.0` does not rewrite other addons. Bundler resolution is what bites:

| Gem | Effect of Admin 2.0 |
| --- | --- |
| `recording_studio_billing` | Gemspec pins `recording_studio_admin ~> 1.1.0`. Billing stays on Admin 1.x until Billing is upgraded. |
| `recording_studio_api` | Dummy/dev pin Admin `1.1.0`. Safe until they bump. Still on Accessible `~> 0.3`. |
| `recording_studio_notifications` | Dummy pin Admin `1.0.0`. Safe until they bump. |
| `recording_studio_webhooks` | Engine and dummy Gemfiles track `RecordingStudio_admin` **without a tag**. After Admin 2.0 lands on `main`, an unpinned `bundle update` will pull 2.0 against Webhooks' RS 3 / Accessible 0.3 stack and fail. Pin Admin `1.2.0` or finish the Webhooks RS 4 upgrade first. |
| `recording_studio_users` | **0.1** (identity / invites / onboarding) does **not** need Admin 2.0. **Phase 6** staff people-admin screens do. |
| `recording_studio_exportable` | Not a runtime dependency of Admin. `0.2.0` needs RS `~> 4.2`. |
| `recording_studio_root_switchable` | `0.5.0` already requires RS `~> 4.1` and Accessible `~> 0.6`. Compatible. |
| Cursor plugin `recording-studio-admin` skill | Default-branch copy still shows `AllowsAccessibleChildren`. Follow this gem's README / this file. |

Tagged 1.x consumers are not broken by publishing 2.0. Anything that floats this GitHub repo without a version or tag will be.

## Related

- [CHANGELOG.md](../CHANGELOG.md#200)
- [README.md](../README.md#requirements)
- RecordingStudio `docs/UPGRADING.md` for 3.x to 4.1
- Accessible CHANGELOG for 0.6.0 and 0.6.1
