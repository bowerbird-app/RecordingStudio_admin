# Upgrading RecordingStudioAdmin

## Upgrading to 2.12.0

Admin `2.12.0` lets a screen list recordings under the current access recording. Declare the allowed types, then read them from the context. A `:within` filter lets a person pick one named item. The screen then shows that item and everything under it. This is an additive feat, not feat!. Screens that do not call `scopeable` behave as before.

```ruby
class PressDownloads < RecordingStudioAdmin::Screen
  key "press_downloads"
  scopeable recordable_types: %w[PressKit Image]
  filter :press_kit, type: :within, label: "Press kit", recordable_type: "PressKit",
         name: ->(recording) { recording.recordable.name },
         all_label: "All press kits"
  filter :recordable_type, label: "Kind"
  filter :person, label: "Who"
  query { |context| context.scoped_recordings }
end
```

`scopeable recordable_types:` takes class names or classes. It adds a `:recordable_type` filter when that filter is not already declared. It does not add a `:within` filter. With nothing picked, `context.scoped_recordings` is the access recording plus descendants from `RecordingStudio::Tree.descendant_ids`. The walk starts at `context.access_recording` and only goes down. A request cannot name another root, a sibling, or a wider blast radius.

`scope` stays the Root Switchable param. `context.scoped_screen_path(:press_downloads, recordable_type: "Image")` writes `recordable_type` on the existing screen path and leaves `scope` and `reach` out of the query.

A `:within` filter requires `recordable_type:`. The param key is the filter key unless `param:` is set. A param of `scope` or `reach` is rejected. The blank option means All. Its label comes from `recording_studio.admin.screens.filters.all_labeled`, so Folder reads "All folders" and Press kit reads "All press kits". `all_label:` replaces that text as written. It accepts a string, a symbol, a dotted i18n key, or a callable. `name:` sets each item's label. With no `name:`, the label is the recordable name, then the title, then the recording id. Blank strings are skipped.

The choices, the query, and the search endpoint share one catalog. A row is included when its type matches the filter, it sits in the kept access subtree, and `RecordingStudioAccessible.authorized?` allows the current actor. The access recording is included only when its type matches. Trashed recordings are left out when `recording_studio_trashable_kept_sql` exists. A kept recording under a trashed ancestor is left out too.

Picking an allowed id walks from that recording with the same cap. The screen relation is that subtree intersected with the scopeable types. Several `:within` filters intersect. An empty intersection is an empty relation. A blank param is All. An unknown id is ignored and does not 403. An id outside the catalog is not applied.

`config.within_search_threshold` defaults to 20. When more rows are allowed, the select uses FlatPack remote search. The route is `GET screens/:key/filters/:filter_key/options` (`screen_filter_options`). The JSON body is `{ items: [{ value:, label: }] }` and does not include All. Search matches the label, ignoring case. `config.max_scoped_recordings` defaults to `5_000`. The cap counts descendants, not the starting recording. Past the cap, the screen and the search endpoint raise `ScopeLimitExceeded` and the controller renders that message with status 422.

Unknown or disallowed `recordable_type` values are ignored, and the allowlist is used. Values are bound with `where`. They are not interpolated into SQL.

Hosts that copied `filter :scope` or a reach query from this unreleased version delete them. There is no deprecation shim.

Horizontal bar charts (`:bar` and `:stacked_bar`) put the whole-number count scale on `xaxis`. `tickAmount`, `max`, `stepSize`, and `forceNiceScale: false` apply there, so a count of N ends on the tick labeled N. The grow animation is off, so the bar is that length on the first paint. Line, column, and area charts keep that scale on `yaxis`. A horizontal bar date chart with more than 12 rows groups those rows into weeks, then months, then years, and labels the buckets with `DateAxisLabels`. Shorter series stay as given. Column, line, and area charts are not regrouped. The category axis uses the count axis step size so FlatPack integer ticks do not clamp the scale.

`label:` may be a string, a symbol or dotted string passed to `I18n.t`, or a callable. Inline fields, modal fields, and the search placeholder use the same label. Select option hashes may still carry their own `label`.

Section links and widget `link_to` callables can call `scoped_screen_path`. The dummy stats section links to the library screen with `scoped_screen_path("library")`.

## Upgrading to 2.11.0

Admin `2.11.0` adds `RecordingStudioAdmin::DateAxisLabels.call`. Built-in date series use it for chart axis labels. `AdminActivityLogsSupport.date_series`, dummy `AdminScreens::Base.date_series`, and `distinct_date_series` keep the same arguments. This is an additive feat, not feat!.

A day series in the current year reads `Nov 12`, then `Nov 13`. The first label includes the year when that time is outside the current year. A later label includes the year when the year changes, as in `Jan 1 2027`. Week axis labels read `Jun 1`. Week tooltips still read `Week of Nov 12`. The first month includes the year, as in `Jan 2026`, and later months in that year stay `Feb`. A single hour includes the day, as in `Jun 15 10am`.

Exact label strings in host and consumer tests may need updating. RecordingStudio_publications and Metrics screens are two consumers.

Full category charts (line, column, bar, and area with string `x` values) set `xaxis.type` to `category` and `labels.rotate` to 0. Short axes also set `xaxis.tickAmount` and hide overlapping ticks. A multi-day hour axis instead labels round hours (every 6, 12, or 24 hours, whichever stays readable) and repeats the day on the first visible tick of each day. `Nov 7 12am` is followed by `12pm`, then `Nov 8 12am`. Count charts also set `yaxis.tickAmount` to 5 and a max one step above the highest count. A flat series used to sit on the top border when every count matched that max. A repeated label such as a later `3pm` keeps that visible text and is plotted as its own category, with a zero-width space on the later x value. `DateAxisLabels.call` still returns the plain label. Compact charts are unchanged. A host `chart_options` hash still overrides these.

### Upgrade Steps

1. Bump the host gem to `2.11.0`.
2. Update tests that assert the previous axis strings.
3. Call `RecordingStudioAdmin::DateAxisLabels.call` when another gem draws its own date axis. Pass `form: :tooltip` for week tooltips.

### Verify the upgrade

```ruby
test "date axis labels show the year only where it changes" do
  travel_to Time.zone.local(2026, 11, 11) do
    labels = RecordingStudioAdmin::DateAxisLabels.call(
      [
        Time.zone.local(2026, 12, 30),
        Time.zone.local(2026, 12, 31),
        Time.zone.local(2027, 1, 1),
        Time.zone.local(2027, 1, 2)
      ],
      bucket: :day
    )

    assert_equal ["Dec 30", "Dec 31", "Jan 1 2027", "Jan 2"], labels
  end
end
```

## Upgrading to 2.10.0

Admin `2.10.0` passes the request `RecordingStudioAdmin::Context` into select filter `values` and `options` callables. Table, chart, and totals already received that context. Write a positional zero-arg callable (`-> { ... }`) or a positional one-arg callable (`->(context) { ... }`). One-arg callables can read `context.controller`, `context.current_actor`, and `context.controller.current_root_recording`. Zero-argument callables still run as `call` with no args. Other arities unchanged.

The context is the same object the controller builds for the request (`controller: self`). Admin does not build a context with a nil controller for filter options. Applying a select filter checks the chosen value against `allowed_values` with that Context, so a one-arg `options` callable is never invoked with zero arguments.

### Upgrade Steps

1. Bump the host gem to `2.10.0`.
2. Leave existing `options: -> { Model.distinct.pluck(:status) }` filters as they are.
3. If filter options should match a table that scopes by the current root, take the context argument:

```ruby
filter :status,
       options: lambda { |context|
         root = context.controller.current_root_recording
         ApiRequest.where(workspace_id: root.id).distinct.order(:status).pluck(:status)
       }
```

### Verify the upgrade

```ruby
test "allowed_values pass request context to callables that accept it" do
  received = nil
  definition = RecordingStudioAdmin::Definitions::FilterDefinition.new(
    :status,
    :select,
    values: ->(context) { received = context; %w[open] }
  )
  controller = Object.new
  context = RecordingStudioAdmin::Context.new(controller: controller, current_actor: :actor)

  assert_equal %w[open], definition.allowed_values(context)
  assert_same context, received
  assert_same controller, received.controller
end
```

## Upgrading to 2.9.3

Admin `2.9.3` uses the FlatPack `v0.1.341` Page Nav spec block. `recording_studio_admin_page_heading` calls `with_back(tooltip:)` for history back and `with_close(href:, tooltip:)` when an anchor is present. It does not pass `anchor_href:`, `anchor_tooltip:`, `back_tooltip:`, or `anchor_label:`. Close still returns to the caller’s `page_nav_anchor_url`. History back still uses `fallback_url` when that anchor is present.

Generated admin root and resource form views call `recording_studio_admin_page_heading`. They do not copy Page Nav arrangement kwargs into host templates. Hosts that prepended the helper or forked views to keep Close can delete those workarounds.

Cards stay on `border:` / `hover:` / `background:`. Card `style:` is gone. Button and Alert still take `style:`.

FlatPack stays `>= 0.1.341` (development tag `v0.1.341`).

### Upgrade Steps

1. Bump the host gem to `2.9.3`.
2. Pin FlatPack `>= 0.1.341` (development tag `v0.1.341`) if you have not already.
3. Replace host `flat_pack_page_nav(..., anchor_href:, anchor_tooltip:, back_tooltip:)` shims with `recording_studio_admin_page_heading`, or with a spec block that calls `with_back` and `with_close`.
4. Delete helper prepends and copied engine views that existed only to keep Close.
5. Move remaining Card `style:` call sites to `background:`, `border:`, and `hover:`.

### Verify the upgrade

```ruby
test "admin page heading uses the flatpack 0.1.341 spec block" do
  helper = File.read("app/helpers/recording_studio_admin/page_nav_helper.rb")

  assert_includes helper, "flat_pack_page_nav"
  assert_includes helper, "with_back"
  assert_includes helper, "with_close"
  refute_includes helper, "anchor_href:"
  refute_includes helper, "anchor_tooltip:"
  refute_includes helper, "back_tooltip:"
  refute_includes helper, "anchor_label:"
end
```

## Upgrading to 2.9.2

Recording Studio core `6.5.0` makes writes fail closed. A missing `config.authorize_write` raises `RecordingStudio::AuthorizationError`. A missing actor raises `RecordingStudio::ActorRequired`. `config.allow_unauthorized_writes` defaults to `false`.

Admin `2.9.2` passes `actor:` on section child writes and admin action audit `record!` calls from the admin context. The dummy host sets a real `authorize_write` that checks Accessible `:edit` on the root recording. `actor.present?` is not a write policy.

Gemspec Recording Studio stays `>= 6.3.0, < 7`. Development and dummy pins stay on core `v6.3.0` until `6.5.0` ships.

### Upgrade Steps

1. Bump the host gem to `2.9.2`.
2. Set `RecordingStudio.configure` `config.authorize_write` before upgrading core to `6.5.0`. Check Accessible (or your host write policy), not only whether an actor is present.
3. Pass `actor:` on jobs, seeds, and other writes that have no `Current.actor`. Admin screens already pass the current actor on section and audit writes.
4. Do not set `config.allow_unauthorized_writes = true` unless you are deliberately keeping the old open writes during a host migration.

### Verify the upgrade

```ruby
test "admin writes pass actor and dummy authorize_write is a real policy" do
  resolver = File.read("lib/recording_studio_admin/section_recording_resolver.rb")
  audit = File.read("lib/recording_studio_admin/admin_action_audit.rb")
  initializer = File.read("test/dummy/config/initializers/recording_studio.rb")

  assert_includes resolver, "actor: @context.current_actor"
  assert_includes audit, "attributes[:actor] = @context.current_actor unless attributes.key?(:actor)"
  assert_includes initializer, "config.authorize_write"
  assert_includes initializer, "RecordingStudioAccessible.authorized?"
  refute_match(/authorize_write\s*=\s*->\(actor:, \*\*\) \{ actor\.present\? \}/, initializer)
end
```

## Upgrading to 2.9.1

Gemspec Recording Studio is `>= 6.3.0, < 7`. Development and dummy pins: core `v6.3.0`, FlatPack `v0.1.341`, Accessible `v0.24.1`. Dummy Exportable `v0.5.12`. `view_component` stays `4.20.0`.

Engine controllers still resolve layout through `recording_studio_layout`. Unset `config.layout` (and unset `surface.layout`) falls through to Recording Studio core's Default Layout. Dummy host views stay as they are.

Engine views already use `flat_pack_page_nav` and `register_page_nav`. Do not pass `back_icon:` or `anchor_label:` — FlatPack `v0.1.341` removed `anchor_label` (`back_icon` is still accepted on the spec, and Admin does not pass it). Card `style:` is removed; Admin cards use `border: :strong`. Button and Badge still take `style:` on this tag.

### Upgrade Steps

1. Bump the host gem to `2.9.1`.
2. Pin Recording Studio `>= 6.3.0, < 7` (development tag `v6.3.0`) and FlatPack `>= 0.1.341` (development tag `v0.1.341`).
3. Pin Accessible `v0.24.1` if you follow the development GitHub tags. Dummy apps that use Exportable pin `v0.5.12`.
4. Keep `view_component` at `>= 4.14` (development `4.20.0`).

### Verify the upgrade

```ruby
test "admin engine uses core default layout and the flatpack 0.1.341 page nav api" do
  source = File.read("app/controllers/recording_studio_admin/application_controller.rb")
  helper = File.read("app/helpers/recording_studio_admin/page_nav_helper.rb")

  assert_includes source, "recording_studio_layout"
  refute_includes helper, "back_icon:"
  refute_includes helper, "anchor_label:"
  refute_includes helper, "recording_studio_page_nav("
  assert_includes helper, "flat_pack_page_nav"
  assert_includes helper, "register_page_nav"
end
```

## Upgrading to 2.9.0

Development and dummy pins: Logs `v0.7.3`, Metrics `v0.7.2`, Trashable `v0.12.2`. Dummy Root Switchable `v0.11.4` and Cache `v0.6.2`. `view_component` stays `4.20.0`. Gemspec floors are unchanged.

The install generator no longer sets `config.layout = "application"`. Leave it unset for core's Default Layout. The admin root generator includes `RecordingStudio::ControllerLayout` and `recording_studio_layout { RecordingStudioAdmin.configuration.layout }`.

Admin no longer appends `"recording_studio_admin"` to Exportable `trusted_export_sources` at request time. It still passes `source: "recording_studio_admin"` to `issue_trusted_token`. Exportable only issues a token when that source is already on the host allowlist. If the host omits that source, Admin exports return no token.

The admin root generator still writes `app/views/layouts/admin.html.erb`. Generated `Admin::BaseController` no longer uses that layout: with `config.layout` unset it falls through to Recording Studio core's Default Layout.

### Upgrade Steps

1. Bump the host gem to `2.9.0`.
2. Pin Logs `v0.7.3`, Metrics `v0.7.2`, and Trashable `v0.12.2` if you follow the development GitHub tags. Dummy apps that use Root Switchable pin `v0.11.4` and Cache `v0.6.2`.
3. Add `recording_studio_admin` to `RecordingStudioExportable` `config.trusted_export_sources`. Without it, Admin exports return no token.
4. If a generated `Admin::BaseController` still has `layout "admin"`, switch it to `recording_studio_layout`. If a generated initializer sets `config.layout = "application"` only as a leftover default, remove that line so core's Default Layout applies.

### Verify the upgrade

```ruby
test "issuing an admin export token does not mutate trusted_export_sources" do
  sources_before = Array(RecordingStudioExportable.configuration.trusted_export_sources).dup

  get "/admin/screens/api_requests/table", params: { columns: ["path"], columns_present: "1" }

  assert_response :success
  assert_equal sources_before, Array(RecordingStudioExportable.configuration.trusted_export_sources)
end
```

## Upgrading to 2.8.2

Admin date range filters pass FlatPack `DateRangeInput` `preset_name:` (the filter `preset_param`, usually `date_range_preset`). Apply writes that hidden field. FlatPack 0.1.341 then dispatches a bubbling `change` on each hidden field it writes, then `flat-pack--flatpack-date-picker:apply` on the picker root with `{start, end, preset}`. Screen filter forms already auto-submit on `change`, so that is the only submit path.

Admin no longer renders a sibling `hidden_field_tag` for the preset, and no longer listens for Apply clicks. Leaving a host click hook next to FlatPack Apply double-submits the form.

Preset labels still use `recording_studio.admin.screens.filters.date_presets`. Each `presets:` entry passes a translated `label:`. A host override of those keys still shows on the picker.

Gemspec FlatPack is `>= 0.1.341`. Development and dummy Gemfiles pin tag `v0.1.341`. Dummy exportable is `v0.5.11` (Accessible `v0.24.0`). Hosts using exportable `>= 0.5.11` still need `config.current_actor`. See [RecordingStudio exportable 0.5.11](#recordingstudio-exportable-0511).

### Upgrade Steps

1. Bump the host gem to `2.8.2`.
2. Pin Flatpack to tag `v0.1.341` (or another `>= 0.1.341` source).
3. Reload kit JavaScript. Do not rebuild Tailwind for this change.
4. Remove any host click handler on `[data-flat-pack-date-picker-command='apply']` that submits the filter form.

### Verify the upgrade

```ruby
test "date range apply uses one auto-submit path and FlatPack preset_name" do
  get "/admin/screens/admin_activity_logs", params: { anchor_url: root_url }

  assert_select "#screen-inline-filters-form input[name='date_range_preset'][data-flat-pack--flatpack-date-picker-target='presetKeyField']",
                count: 1
  assert_select "#screen-inline-filters-form input[name='date_range_preset']", count: 1
  assert_includes response.body, "change-&gt;flat-pack--auto-submit#queueSubmit"
  refute_includes response.body, "queueDateRangeSubmit"
end
```

## RecordingStudio exportable 0.5.11

Hosts using `recording_studio_exportable` `>= 0.5.11` must set `config.current_actor`. The export engine resolves the actor through that setting (`resolve_actor` calls it as `call(controller: controller)`). It does not inherit the host's `Current.actor` before_action. The gem default reads only `Current.actor` and no longer falls back to `controller.current_user`.

Without `config.current_actor`, the export POST returns 403 `Export is not available`.

Call `current_user` in the lambda when that method is public. Do not use `send`.

```ruby
RecordingStudioExportable.configure do |config|
  config.current_actor = ->(controller: nil) { Current.actor || controller&.current_user }
end
```

## Upgrading to 2.8.1

### What Changed

- `RecordingStudioAdmin::Period.from_preset_key(:last_4_weeks)` starts 27 days before the reference date and ends on that date (`Period::LAST_4_WEEKS_LOOKBACK_DAYS`). Flatpack labels that same window "Last 4 weeks". Other week presets still jump by seven days. `Period.from_duration(4.weeks)` is still 28 days back.
- `config.current_root_recording_resolver` and `surface.current_root_recording_resolver` take a callable invoked as `call(context)`. The return value is the root used for the admin root check. A configured resolver is used even when it returns `nil`, which skips the product-root match. Leave the setting unset to keep the previous lookup: the controller's public `current_root_recording`, then RootSwitchable.
- Layout is unchanged. Set `config.layout` or `surface.layout`.

### Upgrade Steps

1. Bump the host gem to `2.8.1`.
2. Screens that default a date filter to `:last_4_weeks` now cover today and the previous 27 days.
3. Replace a prepend that forces `current_root_recording` to return `nil` with:

```ruby
RecordingStudioAdmin.configure do |config|
  config.current_root_recording_resolver = ->(_context) { nil }
end
```

### Verify the upgrade

```ruby
test "last 4 weeks is the 27 day flatpack window" do
  today = Date.new(2026, 9, 8)
  period = RecordingStudioAdmin::Period.from_preset_key(:last_4_weeks, reference_date: today)

  assert_equal today - 27, period.start_date
  assert_equal today, period.end_date
  assert_equal :last_4_weeks, period.preset_key
end

test "a nil root resolver ignores the switched product root" do
  RecordingStudioAdmin.configuration.current_root_recording_resolver = ->(_context) { nil }

  assert_nil RecordingStudioAdmin::Authorization.resolve_current_root_recording(admin_context)
end
```

## Upgrading to 2.8.0

Admin date range pickers pass FlatPack `presets: [{ key: :last_30_days, label: "Last 30 days", days: 31 }, *FlatPack::DateRangeInput::Component::DEFAULT_PRESET_KEYS]`. Charts of type line, column, bar, stacked, area, or radar pass `integer_ticks: true` when every plotted y-value is an Integer. Set `integer_ticks: false` in chart options to opt out. Geo, gauge, pie, and donut charts stay off. Gemspec FlatPack is `>= 0.1.331`. Development and dummy Gemfiles pin tag `v0.1.331`.

### Upgrade Steps

1. Bump the host gem to `2.8.0`.
2. Pin Flatpack to tag `v0.1.331` (or another `>= 0.1.331` source).
3. Rebuild Tailwind (`bin/rails tailwindcss:build`).

## Upgrading to 2.7.3

Housekeeping only. No runtime code change and no dependency pin change. `2.7.2` already shipped the Recording Studio ecosystem pins.

### Upgrade Steps

1. Bump the host gem to `2.7.3`.
2. Keep the `2.7.2` development pins.

## Upgrading to 2.7.2

No runtime code change. Gemspec `recording_studio` is `>= 6.3.0` with no `~>` minor ceiling. Development and dummy Gemfiles pin RecordingStudio GitHub tag `v6.3.0`, Flatpack `v0.1.328`, Accessible `v0.23.1`, Logs `v0.7.1`, Metrics `v0.7.0`, Trashable `v0.12.0`, and `view_component` `4.20.0`. Dummy root switchable is `v0.11.0` and pins Cache `v0.6.0` because that gem requires `recording_studio_cache ~> 0.5`. Accessible `v0.23.1` already accepts Recording Studio `6.3.0` (`~> 6.1`). `test/support/widen_recording_studio_requirement.rb` still rewrites a sibling `recording_studio` requirement that would reject `6.3.0`. Trashable stays `require: false` and query-only.

### Upgrade Steps

1. Bump the host gem to `2.7.2`.
2. Pin RecordingStudio to tag `v6.3.0` and Flatpack to tag `v0.1.328`. Keep the gemspec floor as `>= 6.3.0` with no upper bound.
3. Pin Accessible `v0.23.1`, Logs `v0.7.1`, Metrics `v0.7.0`, and `view_component` `4.20.0`. Trashable stays `v0.12.0`.
4. If the host uses root switchable, pin `v0.11.0` and Cache `v0.6.0`.
5. Rebuild Tailwind (`bin/rails tailwindcss:build`).
6. If a host sets root switchable `config.layout` to a symbol such as `:application_layout`, change it to a layout name string or a callable invoked as `call(controller:)`. The dummy uses `"flat_pack_sidebar"`.
7. Accessible `v0.23.1` adds access-request tables. Run `bin/rails generate recording_studio_accessible:migrations` and `db:migrate` if those tables are not present. The dummy copies the Accessible 0.23.1 request migrations.

## Upgrading to 2.7.1

### What Changed

- Compact widget cards keep `min-h-28` and no longer set `max-h-28`. The title is a full-width line. The metric, change, and mini chart sit on the next line. The mini chart box is `h-14 w-[104px] overflow-hidden`.
- Compact gauge options set `plotOptions.radialBar.dataLabels.value.show` and `name.show` to false. A host `chart_options` formatter is still merged.
- Line and area charts with a single point set `markers.size` to 5 unless the host chart options already set `markers`.
- Full widget cards share `h-[26rem]`, including the skeleton and the turbo frame. The full chart height is 200. A full list renders the first 5 items.
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
