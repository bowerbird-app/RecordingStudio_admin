# Upgrading RecordingStudioAdmin

## Upgrading to 2.7.1

### What Changed

- Compact widget cards keep `min-h-28` and no longer set `max-h-28`. The title is a full-width line. The metric, change, and mini chart sit on the next line. The mini chart box is `h-14 w-[104px] overflow-hidden`.
- Compact gauge options set `plotOptions.radialBar.dataLabels.value.show` and `name.show` to false. A host `chart_options` formatter is still merged.
- Line and area charts with a single point set `markers.size` to 5 unless the host chart options already set `markers`.
- `test/dummy/app/assets/tailwind/application.css` scans this engine with directory `@source` paths, including `lib` and `app/javascript`. The install generator writes the same kind of path for an installed gem.

### Upgrade Steps

1. Bump the host gem to `2.7.1`.
2. Rebuild Tailwind (`bin/rails tailwindcss:build`).
3. If `app/assets/tailwind/application.css` still has the 2.7.0 generator globs for this engine, replace them with directory paths for `app/views`, `app/components`, `app/helpers`, `app/javascript`, and `lib`.

## Upgrading to 2.7.0

Admin `2.7.0` follows RecordingStudio `6.1.0` and Flatpack `0.1.319`. The engine no longer chooses a layout name itself. It asks Recording Studio to resolve one.

### What Changed

- Gemspec depends on `recording_studio` `>= 6.1.0`, `flat_pack` `>= 0.1.315`, and `view_component` `>= 4.14, < 5`.
- Development and dummy Gemfiles pin RecordingStudio tag `v6.1.0`, Flatpack commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (`FlatPack::VERSION` `0.1.319`), Accessible `v0.21.0`, Trashable `v0.12.0`, and `view_component` `4.19.0`. Logs stays `v0.7.0`. Metrics stays `v0.6.1`. Dummy root switchable stays `v0.8.0`. `v0.10.0` still requires Recording Studio `~> 4.1`, and its dropdown template calls `button_attributes`, which Flatpack `0.1.319` removed. The dummy overrides that gem's switch page so close uses `with_close` and the list card uses `border: :default`. Sibling gemspecs that still require Recording Studio below 6 are widened to `>= 6.1.0` by `test/support/widen_recording_studio_requirement.rb` while Bundler loads them.
- `config.engine_layout` and `surface.engine_layout` are `config.layout` and `surface.layout`.
- A layout value is `nil`, `false`, a layout name, or a callable invoked as `call(controller:)`. Anything else raises `ArgumentError`.
- Resolution order is the surface layout when it is not `nil`, then `RecordingStudioAdmin.configuration.layout` when that is not `nil`, then `RecordingStudio.configuration.layout`, then `"recording_studio/default_layout"`.
- Engine controllers call `recording_studio_layout`. They do not hard-code a Recording Studio layout name.
- Section and screen views set `content_for :title` and `content_for :subtitle`. Under the default layout that is the only page heading.
- Back and close use `flat_pack_page_nav(round: true, style: :default, back_tooltip:, anchor_href:, anchor_tooltip:)`.
- Section links and screen buttons use `register_page_nav`. Access avatars stay in `recording_studio_page_nav_right`.
- `recording_studio_page_nav` and the old `:page_nav_back_*` / `:page_nav_anchor_*` slots are gone.

### Upgrade Steps

1. Bump the host gem to `2.7.0`.
2. Pin RecordingStudio to tag `v6.1.0` and Flatpack to commit `1fcbafe94f8eb118f0a22182f63f5110fcc97a56` (or a newer `0.1.319` commit). `view_component` resolves to `4.19.0`.
3. Rename `engine_layout` to `layout` in initializers and `config/recording_studio_admin.yml`.
4. Host views that called `recording_studio_page_nav` should set `content_for :title`, call `flat_pack_page_nav`, and `register_page_nav` for actions.
5. Load `flat_pack/variables`, `flat_pack/application`, and `flat_pack/rich_text` before the Tailwind sheet. Point `@source` at real directories for FlatPack `app/components` and `app/helpers`, and at Recording Studio, Accessible, and root switchable `app/views`, `app/components`, and `app/helpers`. Tailwind 4.3 does not expand globs in `@source`. The dummy links those installed gems into `app/assets/tailwind/gem_sources` before `tailwindcss:build`, including gems under `/usr/local/lib/ruby/gems`. Remove host `--color-fp-*` and `@theme inline` blocks.
6. Replace `include RecordingStudio::UsesDefaultLayout` with `recording_studio_layout { RecordingStudioAdmin.configuration.layout }`.

### Verify the upgrade

```ruby
test "nil layout falls through to the Recording Studio default" do
  RecordingStudioAdmin.configuration.layout = nil
  RecordingStudio.configuration.layout = nil

  get "/admin/sections"

  assert_response :ok
  assert_includes response.body, 'data-recording-studio-default-layout="true"'
end
```

## Upgrading to 2.6.2

No runtime code change. Development and dummy Gemfiles pin Logs GitHub tag
`v0.7.0` and Metrics `v0.6.1`. The gemspec Logs range is still
`>= 0.4.1, < 1.0`.

## Upgrading to 2.6.1

No code change. The gemspec `recording_studio_logs` range is `>= 0.4.1, < 1.0`
(CI tested with 0.5.0).

## Upgrading to 2.6.0

Admin `2.6.0` registers the existing host `admin_audit_logs` table with
RecordingStudioLogs. There is no summary table. Existing rows stay in place.
The table is not copied or partitioned.

### What Changed

- Gemspec depends on `recording_studio_logs` `>= 0.4.1, < 0.6`. Dummy and
  development Gemfiles pin GitHub tag `v0.5.0`.
- Engine registration uses `partition_interval: nil`,
  `root_column: :root_recording_id`, and retention `:indefinite`. There is
  no `aggregate` call.
- `root_recording_id` is added and backfilled from `access_recording_id`.
- Actor, IP, user agent, request id, and error text are not aggregatable.
- `config.logs_retention` defaults to `:indefinite`. Registration always
  passes `:indefinite` to RecordingStudioLogs. A log with no summaries is
  never cleaned by `RetentionCleanupJob`, so a finite window would sit at
  "Cleanup waiting".

### Upgrade Steps

1. Bump the host gem to `2.6.0`.
2. Pin `recording_studio_logs` to GitHub tag `v0.5.0` (allowed range
   `>= 0.4.1, < 0.6`).
3. Install Logs run tables if the host does not already have them:

```sh
bin/rails generate recording_studio_logs:migrations
```

4. Existing hosts copy the Admin logs migration:

```sh
bin/rails generate recording_studio_admin:logs
bin/rails db:migrate
```

New hosts that run `recording_studio_admin:admin_root` already get
`root_recording_id` on `admin_audit_logs`. They still need the Logs run
tables.

That migration adds `root_recording_id` to `admin_audit_logs`, backfills it
from `recording_studio_recordings` via `access_recording_id`, and adds a
root-and-time index. Existing audit rows stay in the same table. Do not
create a summary table.

5. Leave `config.logs_retention` as `:indefinite`. Do not schedule Logs
   partition or retention jobs for this table.

### Verify the upgrade

```ruby
test "admin audit logs stay unpartitioned and indefinite" do
  log = RecordingStudioLogs.registry.log_for("AdminAuditLog")
  assert_nil log.partition_interval
  assert_predicate log, :indefinite?
  assert_equal :root_recording_id, log.root_column
  assert AdminAuditLog.column_names.include?("root_recording_id")
end
```

## Upgrading to 2.5.1

Admin `2.5.1` keeps the Admin activity overview widget on the Admin activity
logs section. The `admin_activity_logs` screen no longer renders that widget.
Date range and Group by on that screen are inline; other filters stay in the
modal. The section link is secondary (not primary).

The generator `AdminRoot` template only enables `section :admin_activity_logs`.
It never placed the widget on the screen. Hosts that copied the old gem screen
definition should drop the screen-level widget.

### What Changed

- `AdminActivityLogsScreen` no longer calls `widget "widgets.admin_activity_logs.activity_overview"`.
- That screen uses `filter_presentation :modal, inline_count: 2`.
- `AdminActivityLogsSection` still references the overview widget and the
  secondary "View admin activity logs" link.

### Upgrade Steps

1. Bump the host gem to `2.5.1`.
2. If a host screen definition still has:

```ruby
widget "widgets.admin_activity_logs.activity_overview"
```

remove that line. Keep the widget on the Admin activity logs section.

### Verify the upgrade

```ruby
test "admin activity overview lives on the section, not the screen" do
  sign_in admin_user

  get "/admin/sections/admin_activity_logs"
  assert_response :ok
  assert_includes response.body, "Admin activity overview"

  get "/admin/screens/admin_activity_logs"
  assert_response :ok
  refute_includes response.body, "Admin activity overview"
  assert_select "#screen-inline-filters-form label", text: "Date range"
  assert_select "#screen-inline-filters-form label", text: "Group by"
end
```

## Upgrading to 2.5.0

Admin `2.5.0` fills empty buckets in `AdminActivityLogsSupport.date_series`.
Callers keep the same arguments. Charts that use this helper now plot a point
for every hour, day, week, month, or year in the filtered `start_date` /
`end_date` window (host time zone, inclusive edges). Empty buckets are `0`.

When the relation has no date bounds, the helper still fills gaps between the
first and last grouped bucket. Series that would exceed `1_000` buckets stay
sparse so hour grouping over a long range cannot explode.

### What Changed

- `date_series` returns ordered `{ x:, y: }` points for every bucket in range,
  including zeros.
- Huge ranges fall back to counts-only output, matching the previous shape.

### Upgrade Steps

1. Bump the host gem to `2.5.0`.
2. Leave existing `date_series` calls as they are.

### Verify the upgrade

```ruby
test "date_series includes zero buckets for empty days" do
  relation = filtered_requests # created_at from Jun 1 through Jun 3, events on Jun 1 and Jun 3

  series = RecordingStudioAdmin::AdminActivityLogsSupport.date_series(relation, bucket: :day)

  assert_equal [
    { x: "Jun 1", y: 1 },
    { x: "Jun 2", y: 0 },
    { x: "Jun 3", y: 1 }
  ], series
end
```

## Upgrading to 2.4.0

Admin `2.4.0` requires Flatpack `~> 0.1.254`. Flatpack `0.1.237` removed Card
`style: :outlined`. Engine screens, widgets, and chart placeholders now pass
`border: :strong`, which is the surface fill with a 2px border.

### What Changed

- Gemspec dependency is `flat_pack ~> 0.1.254`.
- Engine and dummy Gemfiles pin git tag `v0.1.254`.
- Card call sites that used `style: :outlined` use `border: :strong`.

### Upgrade Steps

1. Pin Flatpack to `v0.1.254` or newer:

```ruby
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.254"
```

2. Hosts' own Card `style: :outlined` overrides must move to
   `border: :strong`. Colour `style:` is now `:default`, `:shaded`,
   `:brand`, `:brand_subtle`, or `:gradient`.

### Verify the upgrade

```ruby
test "admin activity logs screen renders" do
  sign_in admin_user

  get "/admin/screens/admin_activity_logs"

  assert_response :ok
end
```

## Upgrading to 2.3.0

Admin `2.3.0` depends on RecordingStudioTrashable `~> 0.10` and loads only the
query-only helpers (`require "recording_studio_trashable/query"`). Product
behavior is unchanged: section recordings and admin-root resolvers still
resolve only non-trashed rows, and host `default_scope`s on `trashed_at` are
preserved (no `_active` unscope).

### What Changed

- `SectionRecordingResolver` uses
  `RecordingStudio::Recording.unscoped.where(...recording_studio_trashable_kept_sql)`
  when Trashable query helpers and the `trashed_at` column exist. The same
  `unscoped` base matches main; the trash filter is a SQL `IS NULL` fragment
  (not `recording_studio_trashable_active`).
- Documented `site_admin_recording_resolver` / access-recording examples use
  `RecordingStudio::Recording.where(...kept_sql).find_by(...)` on the same
  default-scoped relation main used (no added `unscoped`, no `_active`).
- Engine Gemfile pins Trashable at git tag `v0.10.0` with `require: false`.
  Admin does not load the Trashable engine, importmap, `:trashable`
  capability, CopyHelper, or trash metrics.

### Upgrade Steps

1. Add Trashable next to Admin (query helpers only). Trashable's gemspec still
   lists Metrics, so pin that git source for Bundler resolution even though
   Admin does not boot Metrics or Trashable's engine:

```ruby
# Gemfile
gem "recording_studio_metrics", github: "bowerbird-app/RecordingStudio_metrics",
                                tag: "v0.2.0", require: false
gem "recording_studio_trashable", github: "bowerbird-app/RecordingStudio_trashable",
                                  tag: "v0.10.0", require: false
```

2. Bundle and ensure Trashable's `trashed_at` schema is present (Recording
   Studio / Trashable migrations). Admin keeps a column-existence guard and
   falls back to `trashed_at: nil` only when the kept_sql helper is missing.

3. Update host admin-root resolvers that still use
   `find_by(..., trashed_at: nil)` to:

```ruby
RecordingStudio::Recording.where(
  RecordingStudio::Recording.recording_studio_trashable_kept_sql
).find_by(recordable: admin_root)
```

Do not wrap those lookups in `unscoped` or chain `recording_studio_trashable_active`
unless you intentionally want to drop a host `trashed_at` default scope.

### Verify the upgrade

```ruby
assert RecordingStudio::Recording.respond_to?(:recording_studio_trashable_kept_sql)
refute defined?(RecordingStudioTrashable::Engine) # Admin query-only path

admin_root = AdminRoot.find_by!(name: "Admin")
kept = RecordingStudio::Recording.where(
  RecordingStudio::Recording.recording_studio_trashable_kept_sql
).find_by(recordable: admin_root)
assert_equal kept, RecordingStudio::Recording.find_by(
  recordable: admin_root,
  trashed_at: nil
)
```

## Upgrading to 2.2.0

This is a non-breaking upgrade. Rendered English interface text is unchanged.
No public constants, methods, or helpers were renamed or removed.
`Period::QUICK_PRESET_LABELS` stays the public English constant; labels are
translated only when the filter partial passes them to Stimulus.

### What Changed

- Sections search group headings (`Sections`, `Screens`, `In %{title}`) use
  Rails I18n under `recording_studio.admin.sections.index.search_groups`.
- Screen date-preset labels used by the filters Stimulus controller are
  passed as a JSON data attribute built from
  `recording_studio.admin.screens.filters.date_presets`, with English
  fallbacks in the JavaScript if the attribute is absent.
- Existing view `t(...)` calls now include English `default:` values.

Keys added (high level):

| Section | Examples |
| --- | --- |
| `recording_studio.admin.sections.index.search_groups` | Sections, Screens, In %{title} |
| `recording_studio.admin.screens.filters.date_presets` | Today, Yesterday, Last 3 days, … |

Left untranslated on purpose: DSL-registered section/screen/widget titles,
subtitles, and links (including built-in Admin activity logs); Admin column
headers; caller `export_options` text; Devise messages; generator CLI text;
developer-facing errors; `Period` labels returned from public methods.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the keys above in the host's `config/locales`.

## Upgrading to 2.1.0

This is a non-breaking upgrade. Rendered English interface text is unchanged.
Callers that pass their own labels via `content_for`, the admin DSL, or
export/button options keep working. No public constants, methods, or helpers
were renamed or removed.

### What Changed

- Static interface copy in the gem's own views uses Rails I18n keys under
  `recording_studio.admin`.
- The gem ships English only in `config/locales/en.yml`. Rails engines load
  that path by default (no extra initializer), so host `config/locales`
  files load after the gem and can override English. There is no dependency
  on `recording_studio_internationalization`.
- This gem had no prior top-level `recording_studio_admin.*` locale namespace.
  New strings use the nested `recording_studio.admin` keys only.

Keys added (high level):

| Section | Examples |
| --- | --- |
| `recording_studio.admin.navigation` | Go back, Close |
| `recording_studio.admin.sections.index` | Admin sections, search placeholder, empty states, badges |
| `recording_studio.admin.sections.show` | More |
| `recording_studio.admin.screens.filters` | Filters, All |
| `recording_studio.admin.screens.table` | Columns, Export, Apply, Reset, row counts, Actions |
| `recording_studio.admin.widgets` | More, Open %{label}, info aria-labels |

Left untranslated on purpose: DSL-registered section/screen/widget titles and
link labels, caller-provided export button text, filter labels derived from
keys (`humanize`), icon/style tokens, chart series names, and dummy/host views.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the keys above in the host's `config/locales`.

## Upgrading to 2.0.2

No host, schema, or product changes. Admin screens and widgets are unchanged.

This release adds Cloud Agent boot files so a Build can provision a cold
image, skip that work on a warm snapshot, and always fetch the skill pack
last. Rebuild the Cloud Agent environment with Draft off so Build loads the
pack. See [Cursor skills in Cloud Agents](cursor-skills.md).

## Upgrading to 2.0.1

Drop-in bug fix. No configuration, API, or dependency changes.

Screen region endpoints (`/screens/:key/chart`, `/screens/:key/table`, `/screens/:key/table_count`) and widget endpoints (`/screens/:key/widgets/:widget_key`, `/sections/:key/widgets/:widget_key`) exist to answer Turbo Frame fetches. Loading one as a whole page — typing the URL, opening a bookmark, refreshing after Turbo put the frame URL in the address bar, or opening the frame in a new tab — used to return the bare partial, which the browser rendered without the admin layout or any styling.

Those page loads now redirect to the screen or section page that owns the frame, carrying the query string across so sort, filters, page, and columns are preserved.

Frame fetches are unaffected. Admin recognises a page load by the browser's `Sec-Fetch-Dest: document` request header, which browsers send only for top-level navigation; Turbo frame loads, XHR, and server-side requests never set it. Custom JavaScript that fetches these endpoints keeps receiving the fragment.

### Verify the upgrade

Add this integration test to your host app, replacing the screen key with one of your own:

```ruby
test "opening a screen table endpoint as a page lands on the screen" do
  sign_in admin_user

  get "/admin/screens/users/table",
      params: { sort: "email", direction: "asc" },
      headers: { "Sec-Fetch-Dest" => "document" }

  assert_redirected_to "/admin/screens/users?direction=asc&sort=email"

  get "/admin/screens/users/table", headers: { "Turbo-Frame" => "screen-table" }

  assert_response :success
  assert_includes response.body, '<turbo-frame id="screen-table">'
end
```

If your app has custom JavaScript that fetches a frame endpoint, confirm it still receives the fragment. It will, unless it somehow sets `Sec-Fetch-Dest` itself, which browsers forbid.

## Upgrading to 2.0.0

Admin `2.0.0` is a clean break onto Accessible `~> 0.6` and RecordingStudio `~> 4.1`. Hosts still on Accessible `0.3` (or RecordingStudio 3.x) must stay on Admin `1.2.x` until that stack is upgraded.

Section, screen, widget, and resource definition APIs are unchanged. The breaking work is the platform floor, Accessible enablement, and first-staff grants.

### 1. Upgrade the platform gems first

```ruby
# Gemfile
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v4.7.0"
gem "recording_studio_accessible", github: "bowerbird-app/RecordingStudio_accessible", tag: "v0.18.0"
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.207"
gem "recording_studio_admin", github: "bowerbird-app/RecordingStudio_admin" # 2.0.0
```

This gem depends on `recording_studio_accessible ~> 0.6` (which requires RecordingStudio `~> 4.1`) and `flat_pack ~> 0.1.207`. Bundler will reject Admin `2.0.0` next to Accessible `~> 0.3`.

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
| `recording_studio_root_switchable` | Dummy pins `0.8.0` (RS `~> 4.1`, Accessible `~> 0.13`, Metrics `~> 0.2`). Compatible. |
| Cursor plugin `recording-studio-admin` skill | Default-branch copy still shows `AllowsAccessibleChildren`. Follow this gem's README / this file. |

Tagged 1.x consumers are not broken by publishing 2.0. Anything that floats this GitHub repo without a version or tag will be.

## Related

- [CHANGELOG.md](../CHANGELOG.md#201)
- [README.md](../README.md#requirements)
- [README.md](../README.md#frame-endpoints) for the frame endpoints and how a page load is told apart from a frame fetch
- RecordingStudio `docs/UPGRADING.md` for 3.x to 4.1
- Accessible CHANGELOG for 0.6.0 and 0.6.1
