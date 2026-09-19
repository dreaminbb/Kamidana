# Status Bar Foundation Audit — Phase A

## 1. Scope and baseline

- Audit date: 2026-09-19.
- Working branch: `feature/statusbar-foundation`, created from `feature/release-1.0-launch-at-login` at `f18a928` (`Improve terminal and battery widget configuration`).
- This report audits the **working tree**, including changes that already existed before Phase A. Source line references below refer to that snapshot, not necessarily to `f18a928`.
- Existing modifications include battery status colors, their schema/adapter/tests, and formatting changes in the app, CLI, CPU, Music, and `RULE.md`. Existing `.DS_Store`, `package.json`, and `package-lock.json` changes were also preserved. None belongs to this audit commit.
- `Tests/KamidanaTests/musicTest.swift` is an existing **untracked, ignored local file** (`.gitignore:68`), not part of the repository's tracked test suite. SwiftPM nevertheless discovers it inside the test target directory. Its failing assertions must not be attributed to the tracked source baseline without this qualification.
- Phase A changes no application source, tests, example configuration, dependencies, or build rules. `TODO.md` is local task tracking, already excluded by `.gitignore:72`; only this report is intended for the Phase A commit.
- Read: `AGENTS.md`, `RULE.md`, `CONTRIBUTING.md`, and all ten Markdown design documents in `document/`. `AI_RULES.md` does not exist in this checkout. Obsidian application/plugin files are not project design specifications.
- Method: trace decoded fields through validation, adapter, registry, environment, views, managers, and reload lifecycle; inspect all concrete widget implementations, supporting surfaces, and existing tests; retrieve Project #11; run the release build and full test suite.
- No GUI comparison, screen hot-plug experiment, fullscreen experiment, permission reset, or packaged-app login-item experiment was performed. Static findings and runtime hypotheses are distinguished below.

### Source reference legend

Paths in tables use these abbreviations, followed by exact source line numbers.

| Reference | File |
|---|---|
| `V1` | `Sources/KamidanaApp/config/KamidanaConfigurationV1.swift` |
| `CM` | `Sources/KamidanaApp/config/configManager.swift` |
| `Adapter` | `Sources/KamidanaApp/config/KamidanaConfigurationV1Adapter.swift` |
| `App` | `Sources/KamidanaApp/KamidanaApp.swift` |
| `Registry` | `Sources/KamidanaApp/UI/Widgets/WidgetRegistry.swift` |
| `Surface` | `Sources/KamidanaApp/UI/Widgets/SmoothUIModule.swift` |
| `Environment` | `Sources/KamidanaApp/UI/Widgets/WidgetStyleEnvironment.swift` |
| `Settings` | `Sources/KamidanaApp/UI/Widgets/UISettingsStore.swift` |
| `Matrix` | `Sources/KamidanaApp/module/systeminfo.swift` |
| Widget filename | `Sources/KamidanaApp/UI/Widgets/<filename>` |

Other paths beginning with `config/`, `module/`, `Tools/`, `Audio/`, or `UI/` are relative to `Sources/KamidanaApp/`.

## 2. Executive findings

1. The project already has a useful registry, typed YAML decoding, style inheritance, common popup presentation, and tests. It does not need a replacement rendering engine.
2. There is no `Theme` type and no `SmoothUIModule(theme:)` API in current sources. The real API is `SmoothUIModule()`, backed by `WidgetStyleConfig`, optional `KamidanaStyle`, and the singleton's `GlobalColorsConfig` (`Surface:20-118,398-401`). The written convention is ahead of the implementation.
3. Configuration exists in multiple representations: mostly `Decodable` v1 input, legacy runtime `Config`/widget options, per-view fallbacks, and unused `UserDefaults` preferences. The registry does not own decoding of current v1 widget options; the adapter still has a central switch.
4. Several accepted options are ineffective: widget `interval`, `tooltip`, `tooltip_format`, `part_styles`, folder `format`, center click activation, and horizontal-folder hover activation. Display selectors are validated and tested but not connected to window creation.
5. Missing configuration constructs legacy defaults but renders an empty layout through the newer screen-based path. Invalid values generally reject the whole file; invalid colors are instead silently converted. Neither matches the requested per-value fallback policy.
6. Widget identity is regenerated during rendering, and the Island retains a selected runtime value. These are important reload/state risks to resolve before adding multi-window support.
7. Release build passed. Unfiltered tests did **not** pass: 112 tests executed, one skipped, three failed assertions in one ignored local live-state Music test. A diagnostic run excluding that local class passed (105 tests, one skipped). Phase A's investigation is complete, but the unfiltered all-green phase gate remains blocked by the local-test/default-target mismatch.

## 3. Configuration inventory

### 3.1 Sources and reading paths

| Source | Definition / default | Reading and application path | Status |
|---|---|---|---|
| Main YAML | Home directory + `.config/kamidana/config.yaml`; `CM:632-635,1183-1199` | `loadConfig` -> schema detection -> v1 decoder -> validation -> adapter -> runtime layout -> registry -> environments/views | Primary user-facing source, but not the sole runtime model |
| Combined profiles | `global`, `external`, `built_in`, `default_layout`, or arbitrary name/ID profile keys; `V1:1425-1461` | `CM:1070-1075` recognizes combined schema only if one of `external`, `built_in`, `default_layout` exists; `CM:1131-1156` resolves ID, name, type, default, then an arbitrary first dictionary value | Name/ID-only files are not recognized; fallback is nondeterministic without a matching/default profile |
| Single-layout v1 YAML | `global`, `left`, `center`, `right`; `V1:969-1003` | `CM:681-682,1031-1044`; reused for both display classes when no second file exists | Compatibility path |
| Separate legacy monitor YAML | `built_in_monitor.yaml`; `external_monitor` / `built_in_monitor` envelopes; `CM:560-589,674-688,1078-1129` | Decode each role, adapt separately; global runtime settings come from the regular profile | Multiple global sources can disagree; preserve through an explicit migration boundary |
| Legacy Swift defaults | `Config()`; `CM:356-505` | Creates two complete layouts and a palette before loading; adapter also begins with `Config()` | Defaults are duplicated; screen-based rendering bypasses them when v1 config is absent |
| Legacy factory decoder | `WidgetInstance.init(from:)`; `CM:207-232` | One-key legacy widget mapping -> `WidgetFactory.decodeConfiguration` -> synthesized option decoders | Not the current v1 loading path; separate schema/API surface |
| UI preferences | `ui.displayModePolicy`, `ui.collapsedWidgets`; `Settings:15-56` | `UserDefaults` -> unused `StatusBarView.uiSettings` instance (`App:185`) | Stored but no layout consumers |
| CLI login option | Optional `--launch-at-login true/false`; `Sources/KamidanaCLI/main.swift:13-35` | Source-preserving edit of the same YAML (`CM:697-1009`), then watcher or next launch | No independent persistent value; requires an existing valid combined profile and supported block syntax |
| Environment | `PATH`; `Adapter:402-410` | Resolve custom commands and `btop` | Operational input, not a second UI config file; GUI PATH may differ from shell PATH |

`global`, section, and widget styles are merged by `Adapter:348-369`. Nested objects (`padding`, `border`, `shadow`, `animation`) are replaced as whole values when the child supplies one; states with the same name are also replaced, not recursively field-merged. Popup inheritance has a separate chain, initially `global.popup_style ?? global.style` (`Adapter:8-10,80-110,125-126`).

### 3.2 Global, profile, and section fields

Defaults below distinguish a missing decoded field from the eventual runtime fallback. “Required” means the current implementation has no decoded default.

| Field / type | Definition and decoded default | Runtime consumer / behavior |
|---|---|---|
| `global` / object | `V1:991-1000,1437-1442`; empty global object | Adapter and app lifecycle |
| `global.background_mode` / enum | `V1:93-98,814-878`; `single_bar`; other values `per_section`, `per_widget`, `none` | `App:196-203,268-275`; missing v1 configuration instead uses `per_widget` |
| `global.hide_in_fullscreen` / Bool | `V1:825,843,868-869`; `false` | `App:44-61`; startup-only window policy |
| `global.launch_at_login` / Bool | `V1:826,844,870-871`; `false` | `App:23-25,97-100`; startup and valid reload |
| `global.display_targets` / array | `V1:827,854-864`; one `primary` selector; empty is invalid | Resolver exists but has no app caller |
| `display_targets[].kind` / enum | `V1:126-164`; required; `primary`, `secondary`, `built_in`, `external`, `all`, `name`, `id` | `config/KamidanaDisplayTargetResolver.swift:19-57` |
| `display_targets[].name` / String? | `V1:139,161,167-197`; nil; nonempty only for `name` | Exact localized screen name match |
| `display_targets[].id` / UInt32? | `V1:140,162,167-197`; nil; positive only for `id` | Exact Core Graphics display ID match |
| `global.style` / Style | `V1:828,873`; empty Style | Adapter updates only legacy palette `background` and `textPrimary`; surfaces receive the full style |
| `global.popup_style` / Style? | `V1:829,874`; nil | Falls back to global normal style, then section/widget popup overrides |
| `global.bar_padding` / scalar or Insets | `V1:830,875-876`; all zero | `App:126-156`; top/window inset, width and available height; also border visibility |
| Profile keys / mapping | `V1:1437-1454`; every key except `global` becomes a profile; no required pair | Differs from `document/CONFIG.md:40`, which says both profiles are required |
| `left`, `right` / Section | `V1:997-1001,1396-1400`; empty section and widget list | Registry rendering in YAML order |
| `center` / Center | `V1:999,1398`; required | Island rendering; cannot intentionally omit the center |
| Section `background_mode` / enum? | `V1:881-918,922-965`; nil, inherit global | `App:197-199`; values use the global enum, although section-local `single_bar` has no dedicated rendering path |
| Section `activate` / enum? | `V1:883,924`; nil | Widget -> section -> per-view default; center host itself ignores activation |
| Section `style` / Style | `V1:884,925`; empty | Adapter merges with global; section HStacks read their own raw `spacing`, not merged global spacing |
| Section `popup_style` / Style? | `V1:885,926`; nil | Popup inheritance |
| Section `widgets` / array | `V1:917,963-964`; outer sections default `[]`; center list is required | Adapter -> runtime instances; no explicit `enabled` field; omission controls visibility |
| `center.center_default` / String | `V1:927,963,1038-1059`; required, nonempty, references a top-level center widget with a nonempty format | Adapter moves the referenced item to index zero; Island uses the first runtime instance |

### 3.3 Style fields and all nested style values

All normal style fields except `states` decode as nil. They inherit or fall back at rendering time, rather than becoming a fully resolved theme. The same Style type is accepted for popup styles and recursively for states (`V1:345-434`).

| Field / type | Definition | Effective fallback / application |
|---|---|---|
| `background` / String? | `V1:347,417` | Palette background `#1e1e2e`; normal hover uses surface highlight when not explicitly overridden |
| `color` / String? | `V1:348,418` | Palette text or per-widget text/status color; explicit child foregrounds often override parent/state/popup colors |
| `icon_color` / String? | `V1:349,419` | Per-widget icon/status color; ignored by current battery icon path |
| `charging_color` / String? | `V1:350,420` | Battery `#a6e3a1`; existing uncommitted feature |
| `discharging_color` / String? | `V1:351,421` | Battery `#cdd6f4`, with `style.color` applied first by adapter |
| `warning_color` / String? | `V1:352,422` | Battery `#fab387` |
| `danger_color` / String? | `V1:353,423` | Battery `#f38ba8`; these four battery fields are nevertheless accepted for every style |
| `opacity` / Double? | `V1:354,424` | Normal `.6`, hover `.8` (legacy adapter can use normal + `.2`), popup `.96`, Island `.8`; `Surface:49-51,135,235`, `KamidanaIsland.swift:48` |
| `padding` / scalar or Insets? | `V1:355,212-243` | Insets object members `top`, `bottom`, `leading`, `trailing` each default `0`; scalar sets all four. Normal widget fallback top `6`, bottom `9`, horizontal `12` regular / `8` compact, plus `5` per horizontal edge from the wrapper |
| `spacing` / Double? | `V1:356,426` | Left/right section HStacks default `8`; most widget internals ignore it (`App:207,231`) |
| `corner_radius` / Double? | `V1:357,427` | Normal `12` regular / `8` compact, popup/section `12`, Island `16` collapsed / `24` expanded |
| `border` / object? | `V1:358,246-266` | Absent border: surfaces default width `1`; present `{}`: width defaults `0` |
| `border.width` / Double | `V1:247,250,263` | `0` in a decoded border object |
| `border.color` / String? | `V1:248,264` | Normal surface / hover surfaceBorder; popup/Island surfaceBorder |
| `shadow` / object? | `V1:359,269-300` | Normal/section no visible default shadow; popup fallback opacity `.28`, radius `12`, x `0`, y `6` (`Surface:264-269`); Island does not apply shadow |
| `shadow.color` / String? | `V1:270,294` | Palette background |
| `shadow.radius` / Double | `V1:271,295` | `0` in a decoded object |
| `shadow.x`, `shadow.y` / Double | `V1:272-273,296-297` | Each `0`; finite values are not validated |
| `shadow.opacity` / Double | `V1:274,298` | `1` in a decoded object, unlike absent-shadow defaults |
| `material` / enum? | `V1:100-107,360,430` | `ultra_thin`; supports `none`, `thin`, `regular`, `thick`, `chrome` |
| `animation` / object? | `V1:361,303-342` | Wrapper hover default ease-in-out `.2s`; popup/Island/folder/Music transitions use other local definitions |
| `animation.preset` / enum | `V1:109-114,324-340` | Required in an animation object; `none`, `linear`, `ease_in_out`, `spring` |
| `animation.duration_seconds` / Double? | `V1:305,337` | `.2s` for linear/ease-in-out in wrapper |
| `animation.damping` / Double? | `V1:306,338` | `.7` in wrapper spring |
| `animation.response` / Double? | `V1:307,339` | `.5` in wrapper spring |
| `animation.blend_duration` / Double? | `V1:308,340` | `0` in wrapper spring |
| `states` / String -> Style | `V1:362,432` | `[:]`; any state name accepted, only `hover` looked up (`Surface:30-34`); hover padding/corner radius still use the base style |

Numeric ranges are mostly validated in `V1:1298-1355`. Colors are not validated. Popup `padding`, `spacing`, `animation`, and `states` do not have the same behavior as normal styles, even though their type/decoder is shared. State `icon_color` and explicit child text colors are not propagated from wrapper hover state.

### 3.4 Widget input fields

These are the complete stored fields of `KamidanaWidget` (`V1:626-811`).

| Field / type | Default and validation | Reading path / outcome |
|---|---|---|
| `id` / String | Required, nonempty, unique within profile including descendants | Used for validation/default selection, then discarded in runtime `WidgetInstance` in favor of UUID |
| `type` / enum | Required; 14 supported kinds (`V1:437-452`) | Central adapter switch -> runtime typeID -> registry |
| `format` / String? | nil | Side widget label; center fallback after `compact_format` and `normal.format`; folder accepts but ignores it |
| `compact_format` / String? | nil | Center label format; accepted on side widgets but not used there |
| `icon` / String? | nil, only folders/system-action | Folder fallback U+F024B; not a general regular-widget icon override |
| Battery `icon` / object? | nil; separately decoded, `V1:579-624,743-748` | Individual battery icon overrides; full inventory below |
| `folded_icon` / String? | nil, only folders/system-action | Defaults to normal folder icon |
| `direction` / enum? | Folder defaults `below`; `left`/`right` supported; otherwise nil | Adapter -> string-based folder config; system-action fixed below |
| `style` / Style? | nil | Global -> section -> parent folder -> widget inheritance |
| `popup_style` / Style? | nil | Independent popup inheritance chain |
| `activate` / enum? | nil; `hover`/`click` | Information/audio/Bluetooth/Music default hover; folders default click; center host and horizontal hover path do not honor it |
| `motion` / enum? | nil -> `dynamic`; `static` supported | Runtime environment and per-widget transactions; artwork rotation is a separate configured behavior |
| `interval` / Double? | nil; supplied value must be finite and > 0 | Validated only; no adapter/manager consumer |
| `tooltip` / Bool? | nil; only CPU/GPU/memory/network | Validated only; false does not disable the details popup |
| `tooltip_format` / String? | nil; nonempty required when tooltip true | Validated only; never rendered |
| `widgets` / array | `[]`; nonempty required for folder; disallowed for other kinds | Recursive adapter/registry; below-folder expanding-child detection is incomplete |
| `children` / action array | `[]`; nonempty required for system-action | Translated to action buttons inside a below-folder |
| `children[].id` / String | Required, nonempty, profile-wide unique | Validation only; runtime identity regenerated |
| `children[].type` / enum | Required; sleep/reboot/shutdown/logout/lock-screen/about-this-mac | Translated to legacy action names, then `SystemController` |
| `children[].format` / String | Required, nonempty | Literal button label (`SystemActionWidget.swift:17-20`) |
| `children[].icon` / String | Required, nonempty | NerdFontIcon; size omitted at call site |
| `children[].style` / Style | Empty Style | Merged with parent's normal style |
| `part_styles` / String -> Style | `[:]`; accepted only on Music/volume, part names unrestricted | Validated, then discarded; example `media`, `media_slider`, `sound_visualizer` entries are ineffective |
| `command` / String? | nil; nonempty required for custom | Direct process execution on button click; no shell |
| `arguments` / [String] | `[]`; only custom | Passed directly to `Process.arguments` |
| `width`, `height` / Double? | nil -> `700`, `400`; only btop; finite positive values required | Terminal frame and Island sizing |
| `input_management`, `output_management` / Bool? | volume decoder defaults each to true; otherwise nil | Audio controls; runtime `!= false` also defaults to enabled |
| `format_on_action` / String? | nil -> `{artwork} {slider}`; Music-only | `normal.format_on_action` has priority |
| `slider_change` / String? | nil -> textPrimary | Music previous/next color; normal override has priority |
| `slider_pause` / String? | nil -> success | Music play/pause color; normal override has priority |
| `slider_bar` / String? | nil -> accent | Music slider color; normal override has priority |
| `extend` / enum? | nil -> right in left/center, left in right | Standalone Music expansion direction; normal override has priority |
| `artwork_spin` / Double? | nil -> `3s`; finite, >= 0; zero disables | Music rotation; normal override has priority |
| `normal` / object? | nil; Music-only | Contains optional `format`, `format_on_action`, `slider_change`, `slider_pause`, `slider_bar`, `extend`, `artwork_spin`, each nil by default (`V1:503-553`); accepted on side Music too |
| `on_action` / object? | nil; Music-only | `format` defaults to `{title} - {album}` in center and is unused on side Music; `artwork_spin` falls back through normal/top-level to `3s` (`V1:555-577`, `Adapter:217-230`) |

### 3.5 Runtime widget options, defaults, and duplication

The following fields are declared in legacy runtime structs, most of which use synthesized `Codable`. Swift property initializers are **not** missing-key defaults for those synthesized decoders. The v1 adapter normally avoids this issue by constructing the structs directly, then applying a subset of overrides. These fields are not all accepted as YAML keys.

Icon defaults are written as Unicode code points to keep this inventory independent of an installed Nerd Font.

| Runtime config / fields | Exact default(s) | Definition / current use |
|---|---|---|
| CPU `icon` | U+F035B | `CM:26-32`; unused by registered CpuWidget, which embeds the glyph in its fallback format; used only by unregistered CpuGpuWidget |
| CPU `successColor`, `cautionColor`, `dangerColor` | `#a6e3a1`, `#f9e2af`, `#f38ba8` | `CM:28-30`; `CpuWidget.swift:181-184`; adapter also maps general `style.color` to dangerColor |
| CPU `successThreshold`, `dangerThreshold` | `30`, `70` | `CM:31-32`; active, not exposed in v1 |
| GPU `icon` | U+F08AE | `CM:158-160`; unused by GpuWidget fallback format; thresholds 30/70 live in its view |
| Memory `icon`, `iconColor`, `textColor`, `displayFormat` | U+F061A, `#cba6f7`, `#cba6f7`, `xx %` | `CM:35-40`; colors used; icon/displayFormat unused; fallback actually displays used/total GiB |
| Disk `icon`, `iconColor`, `textColor` | U+F02CA, `#fab387`, `#fab387` | `CM:42-45`; icon unused; fallback format embeds a different glyph (U+F00CA) |
| Disk `readIcon`, `writeIcon`, `displayFormat` | U+F0045, U+F005D, `xx %` | `CM:46-48`; read/write icons used, displayFormat unused |
| Network `wiredIcon`, `wirelessIcon`, `offlineIcon` | U+F0C9D, U+F0928, U+F092D | `CM:51-54`; active through format placeholders |
| Network `uploadIcon`, `downloadIcon`, `iconColor`, `textColor` | U+F005D, U+F0045, `#94e2d5`, `#cdd6f4` | `CM:55-58`; active |
| Battery `chargingColor`, `dischargingColor`, `warningColor`, `dangerColor` | `#a6e3a1`, `#cdd6f4`, `#fab387`, `#f38ba8` | `CM:61-65`; battery status overrides in the existing working tree; discharge warning/danger thresholds are local 20/10 |
| Battery `charging_right_now` | U+F0084 | `CM:66`; used only when charging and capacity > 95, not whenever charging |
| Battery `100_capacity`, `90_capacity`, `80_capacity`, `70_capacity` | U+F0079, U+F0082, U+F0081, U+F0080 | `CM:67-70`; Swift fields have leading `_`; v1 names in `V1:593-605` |
| Battery `60_capacity`, `50_capacity`, `40_capacity`, `30_capacity` | U+F007F, U+F007E, U+F007D, U+F007C | `CM:71-74` |
| Battery `20_capacity`, `10_capacity`, `sub_10_charged` | U+F0079, U+F007B, U+F0083 | `CM:75-77`; 20% default repeats the full-battery icon; may be an intentional historical choice, needs confirmation |
| Clock `dateFormat`, `timeFormat`, `locale`, `textColor` | `M/d (E)`, `HH:mm`, `ja_JP`, `#cdd6f4` | `CM:80-85`; only text color is overridable through v1; date locale used, time formatter does not receive it (`ClockWidget.swift:10-20`) |
| Audio `speakerIcon`, `speakerMutedIcon`, `micIcon`, `micMutedIcon` | U+F025, U+F07CE, U+F036C, U+F036D | `CM:87-91`; active, not individually exposed in v1 |
| Audio `activeColor`, `micActiveColor`, `mutedColor`, `textColor` | `#89b4fa`, `#fab387`, `#f38ba8`, `#cdd6f4` | `CM:92-95`; first three used; textColor unused by current AudioWidget |
| Audio `inputManagement`, `outputManagement` | Optional true, optional true | `CM:96-105`; duplicate nil-as-true/default logic alongside v1 |
| Bluetooth `iconConnected`, `iconDisconnected` | U+F00AF, U+F00B2 | `CM:301-307`; based on Bluetooth power, not the number of connected devices |
| Bluetooth `connectedColor`, `disconnectedColor`, `textColor` | `#89b4fa`, `#a6adc8`, `#cdd6f4` | `CM:304-306`; active |
| Music `defaultIcon`, `defaultIconColor` | U+F075A, `#f5c2e7` | `CM:120-122`; active |
| Music `playIcon`, `pauseIcon`, `forwardIcon`, `backwardIcon` | U+F040A, U+F03E4, U+F04AD, U+F04AE | `CM:123-126`; active |
| Music `normalFormat`, `formatOnAction`, `actionMetadataFormat` | `{artwork} {title}`, `{artwork} {slider}`, optional `{title} - {album}` | `CM:127-129`; duplicated fallback/precedence in adapter |
| Music `sliderChangeColor`, `sliderPauseColor`, `sliderBarColor` | nil, nil, nil | `CM:130-132`; view resolves palette roles |
| Music `extend`, `artworkSpinDuration`, `actionArtworkSpinDuration`, `placement` | right, `3`, `3`, standalone | `CM:133-136`; adapter resolves section-specific values |
| Terminal `name`, `terminalPath`, `width`, `height` | Name/path required; `700`, `400` | `CM:139-155`; v1 fixes name to btop and resolves PATH; legacy default layouts hardcode `/opt/homebrew/bin/btop` |
| Folder `name`, `icon`, `iconFolded` | nil, nil, nil | `CM:249-287`; adapter always sets name nil, despite accepted folder `format` |
| Folder `iconColor`, `direction`, `widgets` | `#cba6f7`, `below`, required init list / decoded `[]` | `CM:253-285`; duplicates v1 folder defaults and enum as a String |
| System action `action`, `name`, `icon`, `iconColor` | Required action/icon/color, optional name | `CM:108-113`; adapter's missing child icon color fallback `#cba6f7`; action is a String despite typed input enum |
| Custom `command`, `arguments`, `format` | Required command, `[]`, nil | `CustomWidget.swift:3-17`; label fallback `{output}`, empty output displays command; hardcoded text/icon color `#cdd6f4` |

Battery ranges are 95–100, 85–94, 75–84, 65–74, 55–64, 45–54, 35–44, 25–34, 15–24, 10–14, and everything else (`BatteryWidget.swift:13-29`). The mapping is application behavior, not an additional configuration schema.

#### Label defaults defined outside the input model

`[glyph U+...]` below denotes the literal glyph in a Swift format string, not a supported placeholder syntax.

| Widget | Effective default format | Definition / value source |
|---|---|---|
| CPU | `[glyph U+F035B] {usage}%` | `CpuWidget.swift:17-22`; SystemMatrix CPU percentage or `--` |
| GPU | `[glyph U+F08AE] {usage}%` | `GpuWidget.swift:15-22,105-107`; GPU percentage or `--` |
| Memory | `[glyph U+F061A] {used_gb} / {total_gb} GB` | `MemoryWidget.swift:15-24,116-124`; used GiB, physical memory GiB, percentage |
| Disk | `[glyph U+F00CA] {used}` | `DiskWidget.swift:14-18`; SystemMatrix formatted disk usage |
| Network | `{connection_icon} {network_name} {upload} {upload_icon} {download} {download_icon}` | `NetworkWidget.swift:4-5,19-37`; NetworkManager identity and SystemMatrix rates; no `/s` suffix in this fallback |
| Battery | `{icon} {capacity}%` | `BatteryWidget.swift:54-61`; capacity and charging status |
| Clock | `{date} {time}` | `ClockWidget.swift:10-28`; runtime date/time formatters |
| Bluetooth | `{icon}` | `BluetoothWidget.swift:29-39`; Bluetooth power and connected-device values |
| Volume | `{icon} {volume}%` | `AudioWidget.swift:19-22,188-205`; primary enabled management role |
| Music | `{artwork} {title}`; activated `{artwork} {slider}`; center metadata `{title} - {album}` | `CM:127-129`, `Adapter:209-230`; track metadata or `Not Playing` |
| Custom | `{output}` | `CustomWidget.swift:34-35`; captured process text, or command when empty |
| Folder/system-action launcher | No format rendering; icon and optional legacy name | `WidgetFolder.swift:17-29,63-66`; v1 adapter supplies no name |
| System-action child | Literal required `children[].format`, beside required icon | `SystemActionWidget.swift:12-20` |
| btop compact | `[glyph U+F120]` | `KamidanaIsland.swift:223-228`; validation still requires an explicit format if btop is center_default |

### Documentation contradictions to resolve with the migration

| Document | Current discrepancy |
|---|---|
| `AGENTS.md:87-96`, `CONTRIBUTING.md:87-96` | Refer to enum icons / `nerdfont.toml`; the file is absent and the implementation takes String glyphs. `document/CONFIG.md:147-149` already describes the newer approach. |
| `document/CompactUI.md:3-20,33-34` | Describes active UserDefaults policy and automatic folding; those preferences have no consumers. YAML profiles and folders drive current composition. |
| `document/CONFIG.md:40` | Requires both monitor profiles in prose, while the decoder accepts arbitrary profiles and default_layout. |
| `document/WIDGET_STATES.md:17-18` | Lists CPU/GPU unavailable state as missing, although current CpuWidget/GpuWidget render unavailable content. Device-level visual acceptance is still not established by code presence. |
| `document/CLI.md:4-8` | Lists `kamidana reload config`; CLI registers only Display and the login option (`Sources/KamidanaCLI/main.swift:7-18`). |
| `document/SwiftTermUsage.md:24,57,99-107` | Illustrates a Theme parameter and WindowGroup that are not the current embedded terminal/Island implementation. |
| `CONTRIBUTING.md:49-50` vs `Package.swift:1,8` | Contributor requirements say macOS 14 / Swift 6, while package declares macOS 13 / Swift tools 5.9. Choose supported versions explicitly before release. |

### 3.6 Palette, legacy layout, and preference defaults

| Definition | Fields and defaults | Reading path / assessment |
|---|---|---|
| `GlobalColorsConfig`, `CM:507-528` | `background=#1e1e2e`, `surface=#313244`, `surfaceHighlight=#45475a`, `surfaceBorder=#585b70` | Singleton reads in views/surfaces/terminal; only background is set from current v1 global style |
| Same palette | `textPrimary=#cdd6f4`, `textSecondary=#bac2de`, `textTertiary=#a6adc8` | Only textPrimary is mapped from v1 global style |
| Same palette | `primary=#89b4fa`, `secondary=#cba6f7`, `accent=#f5c2e7`, `success=#a6e3a1`, `warning=#fab387`, `danger=#f38ba8`, `info=#94e2d5`, `caution=#f9e2af` | Active semantic defaults, duplicated in widget structs; not a user-configurable semantic palette in v1 |
| `WidgetStyleConfig`, `CM:6-21` | Regular: `paddingHorizontal=12`, `paddingTop=6`, `paddingBottom=9`, `cornerRadius=12`, `backgroundColorOpacity=.6`, `hoverBackgroundColorOpacity=.8` | Environment/surface fallback, duplicated in adapter |
| Same compact style | `paddingHorizontal=8`, `paddingTop=6`, `paddingBottom=9`, `cornerRadius=8`, `backgroundColorOpacity=.6`, `hoverBackgroundColorOpacity=.8` | `layout(for:)` currently returns regular style even for built-in displays |
| `DisplayLayoutConfig`, `CM:311-352` | `style=defaultNormal`, `barPadding=zero`, `left=[]`, `center=[]`, `right=[]` | Runtime container and separate legacy decoder |
| `Config`, `CM:356-358` | `UserConfigPath=""`, `barTopPadding=0` | No consumers; superseded by ConfigManager resolution and v1 bar padding |
| `Config.externalDisplay`, `CM:361-417` | Left: action folder + audio; center: Music + terminal; right: network, CPU, memory, disk, Bluetooth, battery, clock | Legacy fallback, not the example layout; currently bypassed on missing file |
| `Config.builtInDisplay`, `CM:419-483` | Left/center as above; right: CPU, memory, left-expanding network/disk folder, Bluetooth, battery, clock | Another hand-maintained default layout; GPU absent from defaults but present in sample YAML |
| Default action children, `CM:368-396,426-454` | About This Mac/info color, Sleep/info, Shutdown/danger, Reboot/warning, Logout/primary, Screen Lock/accent | Repeated separately for external/built-in profiles |
| `ui.displayModePolicy`, `Settings:29-31,54` | `auto`; alternatives `alwaysCompact`, `alwaysRegular`; invalid values silently become auto | No consumer beyond storage; obsolete |
| `ui.collapsedWidgets`, `Settings:33-36,55` | `{disk,gpu}`; invalid entries silently removed | No consumer beyond store methods; actual collapsing is YAML folders |
| Environment defaults, `Environment:3-54` | widgetStyle regular; normal/popup/format/activation nil; surface visible true; motion dynamic; popup alignment center | Internal rendering context, not separate persisted settings |

### 3.7 Distributed application-owned defaults

These are not all candidates for public configuration. They must be centralized as operational policy or Theme tokens rather than exposing arbitrary layout coordinates.

| Concern | Values / source | Consequence |
|---|---|---|
| Metric polling | General metrics `3s`, battery `5s`, process list limit `8`; `Matrix:91,130-145` | YAML interval has no effect |
| Music polling / action refresh | `5s` / `.3s`; `module/MusicManager.swift:61-70,188-191` | Independent from widget interval |
| Bluetooth polling | `10s`; `module/BluetoothManager.swift:23-34` | Independent from widget interval |
| Clock polling | `1s`; `ClockWidget.swift:8` | Per-view timer |
| Network details | ipify endpoint, timeout `5s`, minimum public-IP interval `30s`; `module/NetworkManager.swift:112-162` | Operational defaults, not YAML settings |
| LocalSend | UDP `53317`, alias `Kamidana (Mac)`; `module/LocalSendManager.swift:21-25` | Active manager despite unreachable widget |
| Font | Root regular/compact `14`/`13`, semibold monospaced (`App:282`); Nerd Font family fixed to `JetBrainsMono Nerd Font Mono`, icon default `20` (`NerdFontIcon.swift:17-35`) | Most numeric labels inherit monospaced root; explicit child fonts can override it |
| Bar layout | Height budget `600`, side row height `40`, edge insets `10`, top `5`, Island top external `7`; `App:9,221-265,283` | Not Theme-derived |
| Popup / interaction | Popup vertical offset `40`; spring response `.3`, damping `.84`; hover-close delay `.3`; pressed opacity `.88`; `Surface:291,319-335,386` | Shared mechanisms exist, token source missing |
| Island | Expanded `600x300`, collapsed height `32`; terminal +`24` width/+`80` height; spring `.5/.7`; tab `.2s`; `KamidanaIsland.swift:21-32,75,158,193` | Type-specific sizing and separate motion definitions |
| Folder / Music / Bluetooth | Folder spring `.35/.8`; Music ease-in-out `.2s`, close `.15s`; artwork `30fps`; Bluetooth hover `.15s`; `WidgetFolder.swift:115`, `MusicWidget.swift:170,200,289`, `BluetoothWidget.swift:173` | Individual transition implementations remain |
| Logging | DebugRichConsole enabled only under DEBUG by default; `Tools/DebugRichConsole.swift:3-8` | Release login failures are suppressed; config loader instead prints directly |

### 3.8 Reload and fallback behavior

| Setting category | Current behavior | Required consolidation |
|---|---|---|
| Normal YAML styles/layout | Directory watcher calls loader on main queue, posts notification; delegate replaces root view and view also changes an unused token (`CM:1218-1247`, `App:97-109,299-306`) | One validated snapshot and one reload transaction; no duplicate invalidation paths |
| Login item | Synchronizes on launch and successful config notification | Keep the YAML as source of desired state; expose failure/approval status |
| Fullscreen | Applied once in `applicationDidFinishLaunching` | Reconcile window policy on every valid reload |
| Display targets | No runtime effect | Reconcile all selected windows on reload and display events |
| Terminal palette | Applied in makeNSView; updateNSView is empty (`UI/TerminalWindow/TerminalWindow.swift:14-33`) | Update palette in place or explicitly recreate the terminal according to a documented structural policy |
| Legacy UI preferences | Initialized from UserDefaults, unused | Remove dead store/configuration path |
| Missing file at startup | Returns failure and leaves legacy defaults, while screen layout becomes empty | Resolve to a complete usable canonical default snapshot |
| Invalid YAML/known invalid numeric field | Whole-file error; previous snapshot retained on reload | Log path/reason and use field/widget defaults where recoverable; define syntax-error fallback explicitly |
| Invalid color | Accepted, scanner failure ignored, unexpected black/partial values possible | Validate and report before resolving Theme |
| Missing/replaced config directory | Watcher returns silently on open failure; no re-arm logic | Observe/create/re-arm appropriately without repeatedly losing updates |

Directory watching alone is not proof that every in-place file-content write triggers reload. Verify in-place writes, atomic rename, delete/recreate, and missing-directory startup separately.

## 4. Complete widget convention matrix

### Interpretation

- **Wrapper yes** means the actual `SmoothUIModule()` is applied, directly or through `WidgetButtonStyle` (`Surface:330-335`). Literal `SmoothUIModule(theme:)` compliance is absent for **every** row because that API and Theme do not exist.
- **Palette/config** means semantic legacy palette and/or per-widget hex fields are used, not an injected resolved Theme.
- **Root mono** means the current bar supplies a monospaced font (`App:282`), so absence of local `.monospacedDigit()` alone is not a current violation. It is an implicit dependency for standalone previews/reuse.
- System-provided app artwork/process icons are content images, not violations of the no-SF-Symbol widget-icon rule. No `Image(systemName:)` was found in current sources.

| Public widget -> implementation | Common wrapper | Color / Theme compliance | NerdFontIcon size | Dynamic numbers | Other consistency evidence |
|---|---|---|---|---|---|
| `cpu` -> CpuWidget | Yes via button, line 31 | Palette + per-widget threshold colors, lines 15,181-184 | Yes through FormattedWidgetLabel | Root mono; details explicit mono 86,171 and digits 169 | Local graph sizes/corners and popup layout, 44-64,100-126 |
| `gpu` -> GpuWidget | Yes via button, 27 | Palette/config style; no Theme | Yes through label | Root mono; explicit 50,92-94 | Local thresholds 30/70 and dimensions, 112-115 |
| `memory` -> MemoryWidget | Yes via button, 27 | Palette + config colors, 13,23-24 | Yes through label | Root mono; details explicit 44,100 | No compact unavailable state, 14-52 |
| `disk` -> DiskWidget | Yes via button, 23 | Palette + config colors | Compact yes; detail calls omit size and add frames, 44,49 | Root mono; details explicit 54,71 | Local popup frame 320x300, 81 |
| `network` -> NetworkWidget + WiFiConnectionView | Yes via button, 41 | Palette + config; no Theme | Label yes; Wi-Fi row omits size, WiFiConnectionView:152 | Explicit mono 39,137; Wi-Fi RSSI caption lacks explicit mono, WiFiConnectionView:162-163 | Hardcoded detail panel widths and padding; native prominent button tint not theme-resolved |
| `battery` -> BatteryWidget | Yes via button, 67 | Palette + status config; style.icon_color bypassed, 63 | Compact yes; detail calls omit size and use frames, 84-85,134-136 | Root mono; details explicit 97,123,141 | No unavailable compact state; charging threshold behavior needs confirmation |
| `clock` -> ClockWidget | Direct, 31 | Config text/style overrides | Yes through label | Root mono only | Per-view timer/formatters; no date/time format schema fields |
| `bluetooth` -> BluetoothWidget + DeviceRow | Yes via button, 42 | Palette + status config | Yes through label and explicit DeviceRow size 16, 120 | Count root mono; detail mono 154 | Row hover color/opacity/radius/animation local, 156-173 |
| `volume` -> AudioWidget | Yes via button, 25 | Palette + active/muted config | Label and explicit 13/10, 131/157; frame at 133 is a hit target, not font sizing | Root mono; details explicit 124,142 | Local device-list dimensions; both-disabled compact label still derives input values, 188-205 |
| `music` -> MusicWidget | Side normal via button 74, expanded direct 90; center uses Island surface | Palette + config + style | Explicit sizes for artwork/controls, 250,307,381-396 | Elapsed time explicit mono 429; metadata rounded font 132 is appropriate for prose | Own expansion/close/rotation logic and many local sizes, 153-203,279-329,343-354 |
| `widget-folder` -> WidgetFolder | Below via button 32; inline direct 78 | Config color; no Theme | **Missing** size, 28,65 | No own dynamic metric; children inherit | Inline click only despite activate setting; local spring and transitions, 113-129 |
| `system-action` -> folder + SystemActionWidget children | Folder as above; child via button 26 | Config icon + style/palette text | **Missing** size; frame used, SystemActionWidget:13-15 | Not applicable | Synchronous action dispatch, discarded results, 29-45 |
| `custom` -> CustomWidget | Yes via button, 41 | **Literal** `#cdd6f4` fallback in view, 36-37 | Yes through label | Arbitrary output inherits root mono | Process lifecycle is in View, 46-83; no interval or exit-status UI |
| `btop` -> registry inline TerminalView | Island host only; inner terminal has no common widget wrapper | Legacy palette applied once | Compact label uses explicit-size renderer; terminal text is not an icon | Terminal is its own text grid; not applicable | Concrete widget view defined in Registry:68-80; local padding/corner; Theme cannot reload in updateNSView |

All 14 public kinds are covered. There are 14 registry factories, but IDs are not one-to-one names: volume -> audio, btop -> terminal, system-action -> widgetFolder with systemAction children (`Registry:49-140`, `Adapter:128-337`).

### Other existing views and legacy widget artifacts

| View / artifact | Reachability and conventions |
|---|---|
| KamidanaIsland | Always hosted by StatusBarView, even with empty center. Separate surface and material switch; palette/config colors; no shared wrapper; compact generic children inherit root mono. Own motion definitions and special cases for Music/terminal (`KamidanaIsland.swift:24-32,42-64,158-203,210-238`). |
| CpuGpuWidget | Concrete legacy widget, **not registered and no construction call sites**. Wrapper via button; palette; missing constructor sizes at 17/51 and raw GPU font rendering at 136-146; compact numbers lack local mono, details explicitly mono. Must migrate or explicitly retire during approved Phase C, not silently leave a second pattern. |
| LocalSendWidget | Concrete legacy widget, **not registered and no construction call sites**. Direct wrapper at 14; palette; missing icon size at 9; device count lacks local mono. Manager nevertheless runs from StatusBarView. Publicly enabling this widget would be a feature addition, so recommend explicit retirement of dead view/startup path rather than adding it to the schema. |
| SystemControlWidget.swift, SleepWidget.swift, RebootWidget.swift | Each contains only `// Deleted`; no widget implementation to migrate. |
| FormattedWidgetLabel / NerdFontIcon | Renderer supplies constructor size (`FormattedWidgetLabel.swift:49,58`) but has no own dynamic-number policy. Font family and default size are literal (`NerdFontIcon.swift:17-35`). |
| WiFiConnectionView | Audited with Network above; component hosted inside network popup, not an independent registered widget. |

## 5. StatusBarView coupling inventory

`StatusBarView` is in `Sources/KamidanaApp/KamidanaApp.swift:160-315`. It does not contain a per-kind widget switch for the left/right bar. The most significant per-kind presentation switch moved into the Island and remains part of the extension cost.

| Hardcoded responsibility | Evidence | Foundation consequence |
|---|---|---|
| Enable every SystemMatrix capability regardless of configured widgets | `App:162-172` | New backend capability requires editing root service setup; hidden widgets do not reduce collection work |
| Own all service instances | `App:174-186` | Root coupled to LocalSend/network/music/audio/Bluetooth and dead settings store |
| Start LocalSend discovery unconditionally | `App:288`; manager init also starts listener | Background feature remains active without a reachable widget |
| Resolve profile and rebuild adapted layouts inside body | `App:191-203` | Configuration I/O-independent conversion/identity work happens during rendering |
| Duplicate registry/environment wiring | Left `App:208-217`, right `233-242`; repeated in Island and folder | Every environment addition requires multiple edits |
| Hardcode Island as center host | `App:256-266` | Center presentation contract absent from registry; empty/static/click cases not handled uniformly |
| Encode layout and typography constants | `App:207,221-225,231,247-265,282-283` | Theme cannot fully control existing appearance |
| Track only first screen and force unwrap fallback | `App:188,289,296` | Multi-window support and headless-safe construction need separate display context |
| Own monitoring startup in onAppear | `App:286-290` | Lifecycle should be service-driven, especially with multiple bar windows |
| Duplicate config reload notification handling | `App:299-306` vs delegate `97-109` | Token is written but never read; no explicit structural/style-only identity policy |
| Reimplement optional style merge locally | `App:310-314` | One resolved Theme/style snapshot should be handed to the view |
| Adjacent Island-specific Music/terminal content and terminal sizing | `KamidanaIsland.swift:24-32,215-229` | A new center widget can require edits outside its definition, registration, and schema |

## 6. Defects and candidates with evidence

“Confirmed” below means the source path proves the discrepancy (or the test run failed), not that every visual symptom was reproduced. “Hypothesis” requires a targeted experiment. Priorities are relative to this foundation task.

| ID / priority | Finding and evidence | Confidence / verification needed |
|---|---|---|
| F01 / high | **Missing config renders no default widgets.** `CM:660-664` retains `Config()` but `layout(for:)` substitutes empty v1 sections and adapts them (`CM:1159-1168`); that path is called by `App:194`. | Confirmed data path; add a missing-file -> nonempty renderable snapshot test. |
| F02 / high | **Display selectors have no effect.** Single window at `App:30-36`; always `NSScreen.screens.first` at 124/188/289/296. Resolver has no production caller. | Confirmed; existing selector unit tests do not test window reconciliation. Issue #8. |
| F03 / high | **Fullscreen setting does not hot reload.** Collection behavior/listeners set only at `App:44-61`; config handler only syncs login/replaces root (`97-109`). | Confirmed. Cross-application fullscreen behavior is additionally a hypothesis: NSWindow notifications are not a cross-process fullscreen observer, and the private bridge also changes window tags. Test real Spaces/fullscreen on each targeted screen. |
| F04 / high | **Unstable widget identity.** `WidgetInstance.id=UUID()` (`CM:163`); every `StatusBarView.body` calls `layout(for:)`, which adapts anew (`App:194`, `CM:1168`). `ForEach` uses those IDs. | Confirmed regeneration; popup/state loss on unrelated environment updates is a runtime hypothesis. Preserve YAML IDs and resolve outside View.body. |
| F05 / high | **Accepted configuration is dropped.** `interval`, `tooltip`, `tooltip_format`, `part_styles` exist/validate (`V1:638-644,1074-1110`) but do not appear in adapter output or manager inputs. Folder format is passed to environment but WidgetFolder never reads it. | Confirmed. Examples advertise inactive options (`Example/config.yaml:83-84,122-128,146-148`). Implement existing contracts or explicitly migrate/remove with diagnostics. |
| F06 / high | **Inconsistent invalid-value fallback.** Range/unknown-key errors throw and fail the whole load (`V1:19-32,1298-1355`, `CM:691-694`); colors bypass validation and `scanHexInt64` success is ignored (`CM:532-548`). Shadow x/y are not finite-checked. | Confirmed mismatch with requested fallback. Add tests for malformed colors, wrong types, nonfinite values, unknown keys, empty files, and individual invalid widgets. |
| F07 / high | **Network/disk rates are interval byte deltas labeled per second.** Polling is `3s` (`Matrix:132`) but no elapsed-time division is performed (`Matrix:378-385,422-428`). | Confirmed arithmetic defect; steady-traffic readings are approximately three times the per-second rate at nominal cadence. Use measured monotonic elapsed time, including wake/counter reset. |
| F08 / high | **Local test/default-target mismatch and unguarded live Music tests.** The ignored, untracked `Tests/KamidanaTests/musicTest.swift:75-85` assumes paused playback has empty metadata; current manager deliberately retains a valid paused snapshot (`module/MusicManager.swift:92-109`), consistent with `Tests/KamidanaTests/MusicPlayerControllerTests.swift:36-55`. `musicTest.swift:96-104` also invokes playback commands without opt-in. | Reproduced: three assertions failed in that single local test. Preserve the local file; add tracked deterministic coverage and an explicit distinction between default tests and opt-in integration files. Keep paused-track behavior. |
| F09 / medium | **Built-in runtime layout returns regular padding/radius.** Adapter builds separate compact layout (`Adapter:31-48`), but `CM:1168` always returns `.externalDisplay`. | Confirmed; built-in font still changes at App:282, which can mask the padding discrepancy. |
| F10 / medium | **Profile detection and fallback disagree with decoder.** Arbitrary profile keys accepted by `V1:1446-1450`, but schema detection checks only three names (`CM:1074-1075`); unmatched display falls back to `displays.values.first` (`CM:1151`). Empty profile collection also skips global style validation (`V1:1457-1460`). | Confirmed; add name/ID-only, empty, and unmatched-screen resolution tests. |
| F11 / medium | **Center click activation is ignored.** Activation reaches runtime instances (`Adapter:97`) but Island expansion is unconditional onHover (`KamidanaIsland.swift:159,176-201`). | Confirmed. No explicit expansion-disabled representation exists; empty center is rejected by validation. |
| F12 / medium | **Horizontal folders ignore hover activation.** Inline trigger always toggles on click (`WidgetFolder.swift:63`) and installs no hover handler; below path respects activation (`24-42`). | Confirmed; test both directions and activation modes. |
| F13 / medium | **Below-folder restriction misses default popups.** `V1:1271-1275` omits CPU/GPU/memory/disk/battery from expanding kinds unless activate/tooltip was explicitly supplied. Those views default to hover popup. | Confirmed; implicit and explicit activation must resolve before capability validation. |
| F14 / medium | **Watcher lifecycle is incomplete.** Open missing directory returns silently (`CM:1223-1224`), rename/delete has no re-arm logic, and file reading/YAML decoding occurs on main (`CM:1233-1237`). | Confirmed control flow. In-place save loss and deletion/recreation recovery are hypotheses needing filesystem tests; monitor directory entries and file content changes robustly. |
| F15 / medium | **Island selection can retain old configuration after reload.** `selectedTab` is a whole WidgetInstance initialized only when nil (`KamidanaIsland.swift:15,160-163`); no reconciliation against updated centerWidgets. | Hypothesis: SwiftUI can preserve State when root value is replaced; test selected widget removal, reorder, option changes, and style-only reload. |
| F16 / medium | **Terminal has no unavailable state and no update implementation.** Missing btop returns nil in adapter (`Adapter:184-185`); updateNSView is empty (`UI/TerminalWindow/TerminalWindow.swift:28`). | Confirmed silent omission; stale palette/process on retained NSView is a hypothesis. A missing executable should have an explicit configured-widget state and diagnostic. |
| F17 / medium | **System actions execute synchronously and discard failures.** Button invokes `performAction` (`SystemActionWidget.swift:9-10,29-45`), which calls synchronous AppleScript (`module/SystemControler.swift:29-43`). | Confirmed main-thread execution/error loss; blocking severity depends on OS/permission responses. Move execution to a manager and publish state on main. |
| F18 / medium | **Custom command exit status is ignored.** `CustomWidget.swift:69-78` waits, then displays captured output without checking terminationStatus/reason; empty failures fall back to command text. | Confirmed; manager-owned execution should distinguish success/empty/error and implement the approved interval policy. |
| F19 / medium | **Permission metadata typo and incomplete permission UX.** `Resources/Info.plist:21` spells `NSLocalNetworkUsageDescriptio n`; network manager requests location in init (`module/NetworkManager.swift:185-189`); no unified permission status/onboarding UI exists. | Typo and absence confirmed. Actual macOS prompt/failure behavior needs packaged-app testing. Issue #10. |
| F20 / medium | **Release login errors disappear.** Manager logs via DebugRichConsole (`module/LaunchAtLoginManager.swift:65-68`), whose output is disabled by default in release (`Tools/DebugRichConsole.swift:3-8,57-59`); requiresApproval status is silently left alone (`LaunchAtLoginManager.swift:54-63`). | Confirmed. Keep debug noise gated but route actionable configuration/service diagnostics to a release-visible channel. Issue #9. |
| F21 / medium | **Advertised style inheritance has partial consumers.** Section spacing reads raw section style (`App:207,231`); popup content uses explicit global foregrounds (e.g. CpuWidget:47); hover geometry reads base style (`Surface:35-44`); widget foreground/icon colors use base environment. | Confirmed configuration consistency gap. Preserve default appearance while resolving supported token/state precedence once. |
| F22 / low | **Battery icon behavior contradicts its charging label and bypasses generic icon color.** Charging icon only above 95% (`BatteryWidget.swift:14-16`); statusColor always drives icon (`63`); 20% default uses full-battery glyph (`CM:75`). | Code confirmed; desired charging/low-capacity appearance needs user confirmation because battery behavior overlaps pre-existing edits. |
| F23 / medium | **Shared snapshot is read on a worker while mutated on main.** `Matrix:159` copies `self.data` on fetchQueue; publication occurs on main (`193,205`). | Confirmed unsynchronized access pattern; observable races/lost battery updates are hypotheses. Separate backend sample state from published snapshot and test concurrent completions. |
| F24 / low | **Bluetooth count compatibility documentation is inaccurate.** Both `{device}` and `{device_count}` use connected count (`BluetoothWidget.swift:27-36,88-99`), while `document/CONFIG.md:350` describes paired count for the latter. | Confirmed mismatch; decide compatibility contract and document/test it. |

### Additional audit observations

- Memory, disk, and battery disappear when data is nil (`MemoryWidget.swift:14`, `DiskWidget.swift:14`, `BatteryWidget.swift:47`). CPU/GPU already have unavailable text. This is a UI state consistency gap, not proof of a crash.
- Width jitter is not fully solved by monospaced digits: number of digits, units, SSIDs, and track names still change intrinsic width. Preserve current mono inheritance while defining stable metric slots where required; do not incorrectly report every missing local modifier as a violation.
- The release compiler reports four warnings in `Audio/Utilities/AudioProperty.swift`: unused mutable `dataSize` at 120, generic raw pointers at 35/123, and Optional CFString pointer at 96. These are confirmed warnings, not demonstrated memory corruption. A typed CoreAudio boundary review is appropriate before changing this code.
- `App:188` force-unwraps `NSScreen.main` when the screen array is empty. Headless/transient-display crash is a hypothesis. The proposed display coordinator should represent zero screens without constructing that view.
- `KamidanaFormatRenderer.render` uses dictionary reduction (`FormattedWidgetLabel.swift:4-7`), so placeholder-like text inside a replacement may be substituted again depending on iteration order. This is a hypothesis for unusual custom/metadata strings; a single-pass tokenizer would make the rule deterministic if confirmed.

## 7. GitHub Project #11

Retrieved successfully using the requested command:

```sh
gh project item-list 11 --owner dreaminbb
gh project item-list 11 --owner dreaminbb --format json --limit 100
```

The complete response contained 19 items. The following **14 are not Done by Project status**. Project status is not treated as proof of implementation; for example, #9 is TODO although code and tests already exist. This audit does not edit Project items or close issues.

| Issue | Title | Project status / release label | Proposed 1.0 classification | Rationale / implementation evidence |
|---|---|---|---|---|
| #14 | Define custom theme specification (YAML) | In review / v1.0, P0 | **Required** | Typed styles exist, but no resolved Theme, complete palette, or unified defaults. Phase B canonical schema; Phase C full rendering migration. |
| #19 | Collapsible system widget groups | In review / v1.0, P1 | **Required** | Existing folder feature; fix implicit-expander validation/activation and include it in the shared structure. |
| #13 | Configurable widget visibility and reordering | In review / v1.0, P0 | **Required** | Arrays already support removal/reordering; missing default rendering, unstable IDs, empty center, and reload lifecycle undermine daily use. |
| #8 | Support multi-monitor display selection | In progress / v1.0, P0 | **Required** | Public selector schema/test coverage exists but window lifecycle ignores it. A separate local branch is at ancestor `5999f1b` with no commits ahead of the audited base; no alternate implementation was imported. |
| #17 | Implement artwork caching for Music widget | TODO / v1.1+, P2 | Deferred | Current-track fetch deduplication exists, but persistent/recent-track caching is a new optimization, outside foundation scope. |
| #1 | Implementation - Caffeinate feature | TODO / v1.1+, P2 | Deferred | New feature, outside scope. |
| #18 | Add CAVA audio visualizer widget | TODO / v1.1+, P2 | Deferred | New widget/integration; inactive `sound_visualizer` style does not justify implementing it here. |
| #15 | Add auto-update support via Sparkle framework | TODO / v1.0, P1 | **Decision required; recommend deferring from this task** | Project marks it for 1.0, but it adds a dependency and a release/update distribution workflow. It is not required for the requested extensibility criteria. Explicit approval is required before adding Sparkle or changing release scope. |
| #4 | Implementation - Force quit current app | TODO / v1.1+, P2 | Deferred | New action feature, outside scope. |
| #5 | Implementation - norification bottom | TODO / v1.1+, P2 | Deferred | Native notification-panel button is a new feature. |
| #2 | Clock / Calendar display | TODO / v1.0, P1 | Clock retained; **Calendar excluded** | Clock already exists. User explicitly excludes unstarted Calendar. Repair existing clock configuration/defaults as foundation work without adding Calendar. |
| #10 | Permission request UI and onboarding flow | TODO / v1.0, P0 | **Required** | Existing Bluetooth/location/system-action/music features need coherent status and recovery guidance. Request only permissions needed by enabled functionality; use system frameworks. |
| #6 | Implementation - weather widget | TODO / v1.1+, P2 | Excluded | Explicitly excluded unstarted feature. |
| #9 | Implement Launch at Login option | TODO / v1.0, P0 | **Required, mostly implemented** | SMAppService adapter, synchronization, CLI, five service tests already present. Complete diagnostics/approval UX and packaged-app verification rather than duplicating implementation. |

Project Done items: #21 Island centering, #23 icon/font consistency, #22 live config reloading, #16 network details, #3 fullscreen visibility. F03/F05/F09/F14/F21 demonstrate that Done status does not guarantee all current acceptance criteria. Issue #16 mentions packet loss, while the current panel displays local IP/DNS/public IP and rates (`NetworkWidget.swift:111-115`); do not add a network-health feature under this foundation task just to reconcile a previously completed roadmap item.

## 8. Build and test evidence

| Command | Result |
|---|---|
| `make build` | Passed, production build, 42.60 seconds; four existing CoreAudio utility warnings described above. |
| `swift test` | Build succeeded; suite failed. 112 tests executed, one skipped, three failed assertions in `MusicManagerTests.testClearInfoWhenNothingPlaying` at `Tests/KamidanaTests/musicTest.swift:83-85`. Test execution approximately 5.48 seconds. |
| `swift test --skip MusicManagerTests` | Diagnostic isolation run passed: 105 tests, one skipped, zero failures, approximately 1.84 seconds. This excludes only the ignored local class; it does not replace the requested final unfiltered gate. |
| Bare `make` | Not used as a verification command: first target is `run`, which executes the app (`Makefile:12-14`). |
| `make test` | No such target exists in the current Makefile. Phase B should add a deterministic build-and-test default/target while retaining explicit `make run`. |

The tests for configuration, adapter, display selectors, and login service all passed in the full run. The one skipped test is opt-in live Spotify integration (`Tests/KamidanaTests/MusicPlayerControllerTests.swift:127-133`). The older local `musicTest.swift` suite is not behind that gate and incorrectly treats paused metadata as invalid. `git ls-files -- Tests/KamidanaTests/musicTest.swift` returned no entry; `git check-ignore -v` identified `.gitignore:68`. Re-running until a favorable live state happens would not establish correctness.

No source changes were made to turn this baseline green in Phase A. Proceeding to Phase B requires acknowledging this known baseline failure and approving its repair. The final completion gate is still a passing build and full default test suite, not a filtered green subset.

## 9. Proposed Phase B plan — approval required

This is a proposal, not authorization or implemented work.

1. **Restore a meaningful test/build gate.** Add a default `make` verification path (build + tests) and `make test`, retain `make run`; add tracked injected paused/empty snapshot coverage and distinguish default test sources from ignored local integration files while preserving the local file. Gate actual media-control integration tests. This must be an explicit test-target policy, not permanently filtering a failing class in the Makefile. Review the compiler warnings at the typed API boundary without unrelated reformatting.
2. **Choose one canonical Codable configuration snapshot.** Keep `~/.config/kamidana/config.yaml` and existing v1 user-facing names as the primary interface. Normalize legacy one-/two-file inputs at a compatibility boundary. Resolve defaults/inheritance once, preserve configured IDs, keep service policy separate from visual tokens, and remove dead UserDefaults/preferences and legacy runtime duplicates as their consumers are migrated.
3. **Define recovery explicitly.** Missing file/fields use a complete default layout; empty center is valid when intentionally configured. Bad scalar values log field path, reason, and replacement. An unusable custom command or unknown widget becomes an explicit unavailable/disabled item instead of running an invented command. Syntactically unreadable documents need an agreed whole-document fallback policy. No silent accepted-but-unused fields remain.
4. **Finish required Project work.** #13 layout identity/visibility/reorder/reload; #14 schema/resolved theme model; #19 folder capabilities/activation; #8 per-display window coordinator and scoped configuration; #9 login status/errors and reload consistency; #10 permission status/onboarding for current functionality. Include issue numbers in implementation commits and keep Phase B commits separate from Phase C.
5. **Fix confirmed foundation defects.** Resolve F01-F21/F23 where applicable, verify the reload/selection/watcher hypotheses with targeted tests, and agree F22/F24's visible compatibility semantics. Correct per-second rates using elapsed time, move process/action lifecycles out of views, provide unavailable states, and make color/interaction changes diagnosable. All durable user-config changes should follow the same successful-reload transaction.
6. **Verify.** Full `make` gate, parser/default/recovery/identity tests, window reconciliation tests, and focused manager tests. Report GUI acceptance still requiring real-device confirmation separately from automated coverage.

### Proposed configuration consolidation

| Current redundancy | Proposed destination |
|---|---|
| v1 input + legacy Config/layout + widget-specific default structs | Codable canonical configuration and resolved runtime snapshot; compatibility decoder only at input boundary |
| GlobalColorsConfig + per-widget color copies + literal fallback colors | Resolved semantic Theme with validated per-widget overrides |
| WidgetStyleConfig + KamidanaStyle + per-surface fallbacks | Theme metrics/surface/state tokens with a documented normal/popup inheritance contract |
| UserDefaults display policy/collapsed set | Remove dead store; use display profiles/selectors and explicit folders already represented in YAML |
| UserConfigPath / barTopPadding | Remove; use ConfigManager path resolution and global.bar_padding |
| Unused memory/disk displayFormat and unused registered-widget icon fields | Format model and its configured glyph tokens |
| interval / tooltip / tooltip_format / part_styles | Implement their existing useful contracts or migrate/remove unsupported subparts with a warning; do not leave no-op settings or implement CAVA |
| Music top-level/normal/on_action repetitions | Normalize to typed normal/activated options with one precedence rule, retaining input compatibility |
| Display global copies and singleton active palette | One shared global config plus per-display resolved context |

## 10. Phase C direction — separate approval required later

- Define a widget contract that owns typed options, validation/default resolution, compact/expanded rendering, tab metadata, capability requirements, and service dependencies. Type erasure belongs at the registry boundary.
- Provide a shared host for environment injection, surfaces, formatting/metric typography, interaction state, unavailable state, and motion. Left/right/center/folder should all instantiate through that host.
- Make the accepted extension path exactly: one widget definition file, one registration line, one typed schema addition. Remove central per-kind adapter and Island special cases from the addition path.
- Centralize color, spacing, radius, font/icon sizing, hover, and animation duration/curve in Theme. Use shared animation/interaction modifiers rather than per-widget withAnimation blocks. Geometry calculations remain application-owned; user config must not become arbitrary positioning instructions.
- Migrate all 14 public widget kinds and Island/supporting UI. Explicitly retire the two unregistered legacy widgets or migrate them if the maintainer chooses to retain internal implementations. Empty placeholder files can be removed only as part of this approved structural cleanup.
- Use CPU as the proposed reference implementation: metric formatting, thresholds, data-unavailable state, popup, service dependency, and shared interaction are representative. Document exact extension steps and a checklist in the contributor/design documentation.
- Preserve existing default sizes/colors/timing as initial tokens. Intentional changes (correct rate values, true compact padding, activation/tooltip behavior, explicit missing-data states, working display selection) must be called out individually rather than hidden in a visual redesign.

## 11. Decisions needed before implementation

1. Approve Phase B with the existing test failure treated as its first repair, rather than an already-passing Phase A gate.
2. Confirm deferring Sparkle #15 for this foundation task despite its Project v1.0 label; adding the dependency requires separate explicit approval.
3. Choose recovery for syntactically unreadable YAML during reload: the user's task suggests defaults; keeping the last good snapshot instead is a different policy and must be explicit. Recommended for strict task alignment: log the document error and apply canonical defaults.
4. Confirm battery precedence given the pre-existing edits: recommended status-specific color overrides generic icon_color, charging glyph at every charging capacity, corrected low-capacity default glyph. The first rule preserves the working-tree direction; the latter two visibly change behavior.
5. Confirm `{device_count}` compatibility: recommended preserve existing connected-count behavior and correct the documentation, keeping `{device}` as the same count.
6. Approve explicit retirement of unreachable CpuGpuWidget/LocalSendWidget and inactive LocalSend startup in Phase C, or require internal migration while leaving them out of the public schema.

## 12. Phase A outcome

- Configuration inventory, complete widget matrix, root coupling list, evidence-backed defects, and Project classification are complete.
- Source/UI behavior has not been changed by Phase A.
- Release build is green; default test suite is blocked by F08. Existing warnings and manual visual/hardware checks remain documented.
- No configuration has yet been removed or merged. Sections 9–11 are proposed work and decisions for approval, not completed changes.
